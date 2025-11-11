import React, { useState, useEffect, useRef } from "react";
import axios from "axios";
import classNames from "classnames";
import { isMobile } from "react-device-detect";
// Remove Dashboard import
// CSS imports removed - will be handled at the application level

// Cloudinary configuration
const CLOUDINARY_CLOUD_NAME = "framefox";
const CLOUDINARY_UPLOAD_PRESET = "framefox_default";
const CHUNK_SIZE = 10 * 1024 * 1024; // 10MB chunks - optimal balance for most scenarios

// Analytics tracking function
const trackEvent = (eventName, properties = {}) => {
  if (
    typeof window !== "undefined" &&
    window.analytics &&
    window.analytics.track
  ) {
    window.analytics.track(eventName, properties);
  } else {
    console.log("Analytics event:", eventName, properties);
  }
};

const Uploader = ({
  upload,
  post_image_url,
  shopify_customer_id = 7315072254051,
  is_pro = true,
  onUploadSuccess,
}) => {
  const [percentCompleted, setPercentCompleted] = useState(0);
  const [resolution_acceptable, setResolutionAcceptable] = useState(true);
  const [fileUploading, setFileUploading] = useState(false);
  const [isFinishing, setIsFinishing] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [resolution_warning, setResolutionWarning] = useState("");
  const [isDragOver, setIsDragOver] = useState(false);
  const [currentFile, setCurrentFile] = useState(null);

  // Calculate max file size based on user type
  const MAX_FILE_SIZE = is_pro ? 200 * 1024 * 1024 : 100 * 1024 * 1024; // 200MB for pro, 100MB for regular
  const MAX_FILE_SIZE_MB = Math.round(MAX_FILE_SIZE / (1024 * 1024));

  // Refs for managing upload state
  const uploadAbortController = useRef(null);
  const dropzoneRef = useRef(null);

  // Generate unique upload ID for chunked uploads
  const generateUniqueUploadId = () => {
    return `uqid-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  };

  // Handle successful upload response
  const handleUploadSuccess = (result) => {
    setPercentCompleted(100);
    setFileUploading(false);
    setIsFinishing(false);
    setIsSaving(true);

    const image = {
      width: result.width,
      height: result.height,
      filename: result.original_filename,
      external_id: result.public_id,
      host: "cloudinary",
      path: "path",
      source: "direct",
      url: result.secure_url,
      filesize: result.bytes,
      format: result.format,
      shopify_customer_id: shopify_customer_id,
    };

    // Send to server
    const apiAuthToken = window.FramefoxConfig?.apiAuthToken;
    axios
      .post(post_image_url, { image }, {
        params: apiAuthToken ? { auth: apiAuthToken } : {}
      })
      .then((response) => saveSuccess(response.data))
      .catch((error) => {
        console.error("Error saving image:", error);
        setFileUploading(false);
        setIsFinishing(false);
        setIsSaving(false);
        setResolutionAcceptable(false);
        setResolutionWarning(
          "There was an error saving your image. Please try again."
        );
      });
  };

  // Chunked upload for files larger than 100MB
  const uploadFileChunked = async (file) => {
    const uniqueUploadId = generateUniqueUploadId();
    const totalChunks = Math.ceil(file.size / CHUNK_SIZE);
    let currentChunk = 0;

    // Upload speed tracking
    const uploadStartTime = Date.now();
    let totalBytesUploaded = 0;
    let lastProgressTime = uploadStartTime;
    let lastBytesUploaded = 0;

    uploadAbortController.current = new AbortController();

    console.log(`🚀 Starting chunked upload: ${file.name}`);
    console.log(`📊 File size: ${(file.size / (1024 * 1024)).toFixed(2)}MB`);
    console.log(`📦 Total chunks: ${totalChunks}`);
    console.log(`🔧 Chunk size: ${(CHUNK_SIZE / (1024 * 1024)).toFixed(2)}MB`);

    const uploadChunk = async (start, end) => {
      const chunkStartTime = Date.now();
      const chunkSize = end - start;

      const formData = new FormData();
      formData.append("file", file.slice(start, end));
      formData.append("cloud_name", CLOUDINARY_CLOUD_NAME);
      formData.append("upload_preset", CLOUDINARY_UPLOAD_PRESET);
      const contentRange = `bytes ${start}-${end - 1}/${file.size}`;

      console.log(
        `📤 Uploading chunk ${currentChunk + 1}/${totalChunks} (${(
          chunkSize /
          (1024 * 1024)
        ).toFixed(2)}MB)`
      );

      // Show intermediate progress while chunk is uploading
      const chunkProgressInterval = setInterval(() => {
        const currentTime = Date.now();
        const chunkDuration = (currentTime - chunkStartTime) / 1000;

        // Estimate chunk completion based on average speed so far
        if (totalBytesUploaded > 0) {
          const totalDurationSoFar = (currentTime - uploadStartTime) / 1000;
          const avgSpeed = totalBytesUploaded / totalDurationSoFar; // bytes per second
          const estimatedChunkProgress = Math.min(
            1,
            (avgSpeed * chunkDuration) / chunkSize
          );
          const estimatedBytesForThisChunk = chunkSize * estimatedChunkProgress;
          const estimatedTotalBytes =
            totalBytesUploaded + estimatedBytesForThisChunk;
          const estimatedProgress = Math.min(
            100,
            (estimatedTotalBytes / file.size) * 100
          );

          setPercentCompleted(Math.round(estimatedProgress));
        }
      }, 500); // Update every 500ms

      try {
        const response = await fetch(
          `https://api.cloudinary.com/v1_1/${CLOUDINARY_CLOUD_NAME}/auto/upload`,
          {
            method: "POST",
            body: formData,
            headers: {
              "X-Unique-Upload-Id": uniqueUploadId,
              "Content-Range": contentRange,
            },
            signal: uploadAbortController.current.signal,
          }
        );

        // Clear the progress interval once the chunk is complete
        clearInterval(chunkProgressInterval);

        if (!response.ok) {
          throw new Error(
            `Chunk upload failed with status: ${response.status}`
          );
        }

        const chunkEndTime = Date.now();
        const chunkDuration = (chunkEndTime - chunkStartTime) / 1000; // seconds
        const chunkSpeedMbps = chunkSize / (1024 * 1024) / chunkDuration; // MB/s

        totalBytesUploaded += chunkSize;
        const totalDuration = (chunkEndTime - uploadStartTime) / 1000; // seconds
        const avgSpeedMbps = totalBytesUploaded / (1024 * 1024) / totalDuration; // MB/s

        // Calculate instantaneous speed (last 1 second)
        const timeSinceLastProgress = (chunkEndTime - lastProgressTime) / 1000;
        const bytesSinceLastProgress = totalBytesUploaded - lastBytesUploaded;
        const instantSpeedMbps =
          timeSinceLastProgress > 0
            ? bytesSinceLastProgress / (1024 * 1024) / timeSinceLastProgress
            : 0;

        console.log(
          `✅ Chunk ${currentChunk + 1}/${totalChunks} complete: ` +
            `${chunkDuration.toFixed(1)}s, ` +
            `${chunkSpeedMbps.toFixed(2)}MB/s this chunk, ` +
            `${avgSpeedMbps.toFixed(2)}MB/s average, ` +
            `${instantSpeedMbps.toFixed(2)}MB/s current`
        );

        // Estimate time remaining
        const remainingBytes = file.size - totalBytesUploaded;
        const etaSeconds =
          remainingBytes / (totalBytesUploaded / totalDuration);
        const etaMinutes = Math.ceil(etaSeconds / 60);

        if (currentChunk < totalChunks - 1) {
          console.log(`⏱️  ETA: ${etaMinutes}min remaining`);
        }

        currentChunk++;

        // Calculate progress based on actual bytes uploaded (0-100%)
        const uploadProgress = Math.min(
          100,
          (totalBytesUploaded / file.size) * 100
        );
        setPercentCompleted(Math.round(uploadProgress));

        // Update progress tracking
        lastProgressTime = chunkEndTime;
        lastBytesUploaded = totalBytesUploaded;

        if (currentChunk < totalChunks) {
          const nextStart = currentChunk * CHUNK_SIZE;
          const nextEnd = Math.min(nextStart + CHUNK_SIZE, file.size);
          await uploadChunk(nextStart, nextEnd);
        } else {
          // Set progress to 100% and show "Finishing" state
          setPercentCompleted(100);
          setIsFinishing(true);

          const result = await response.json();
          const totalUploadTime = (Date.now() - uploadStartTime) / 1000;
          const finalAvgSpeed = file.size / (1024 * 1024) / totalUploadTime;

          console.log(`🎉 Chunked upload complete!`);
          console.log(`📈 Total time: ${totalUploadTime.toFixed(1)}s`);
          console.log(`📊 Average speed: ${finalAvgSpeed.toFixed(2)}MB/s`);
          console.log(`📋 Upload ID: ${uniqueUploadId}`);

          handleUploadSuccess(result);
        }
      } catch (error) {
        // Clear the progress interval on error
        clearInterval(chunkProgressInterval);

        if (error.name === "AbortError") {
          console.log("Upload was cancelled");
          return;
        }
        console.error("Error uploading chunk:", error);
        setFileUploading(false);
        setIsFinishing(false);
        setResolutionAcceptable(false);
        setResolutionWarning(
          "There was an error uploading your image. Please try again."
        );
        const errorTime = Date.now();
        const timeBeforeError = (errorTime - uploadStartTime) / 1000;

        console.error(
          `❌ Chunk upload error after ${timeBeforeError.toFixed(1)}s:`
        );
        console.error(
          `📊 Progress: ${currentChunk}/${totalChunks} chunks completed`
        );
        console.error(`📋 Error details:`, error);

        trackEvent("Upload: Chunked Error", {
          error_message: error?.message || error?.toString() || "Unknown error",
          chunk: currentChunk,
          total_chunks: totalChunks,
          time_before_error: timeBeforeError,
        });
      }
    };

    const start = 0;
    const end = Math.min(CHUNK_SIZE, file.size);
    await uploadChunk(start, end);
  };

  // Regular upload for files smaller than or equal to 100MB with real-time progress
  const uploadFileRegular = async (file) => {
    const uploadStartTime = Date.now();

    console.log(`🚀 Starting regular upload: ${file.name}`);
    console.log(`📊 File size: ${(file.size / (1024 * 1024)).toFixed(2)}MB`);

    const formData = new FormData();
    formData.append("file", file);
    formData.append("cloud_name", CLOUDINARY_CLOUD_NAME);
    formData.append("upload_preset", CLOUDINARY_UPLOAD_PRESET);

    uploadAbortController.current = new AbortController();

    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();

      // Track upload progress
      xhr.upload.addEventListener("progress", (event) => {
        if (event.lengthComputable) {
          const uploadProgress = (event.loaded / event.total) * 100;
          setPercentCompleted(Math.round(uploadProgress));

          const currentTime = Date.now();
          const elapsed = (currentTime - uploadStartTime) / 1000;
          const currentSpeed = event.loaded / (1024 * 1024) / elapsed;

          console.log(
            `📤 Upload progress: ${Math.round(uploadProgress)}% ` +
              `(${(event.loaded / (1024 * 1024)).toFixed(1)}MB / ${(
                event.total /
                (1024 * 1024)
              ).toFixed(1)}MB) ` +
              `@ ${currentSpeed.toFixed(2)}MB/s`
          );
        }
      });

      // Handle upload completion
      xhr.addEventListener("load", () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          // Set progress to 100% and show "Finishing" state
          setPercentCompleted(100);
          setIsFinishing(true);

          const uploadEndTime = Date.now();
          const totalUploadTime = (uploadEndTime - uploadStartTime) / 1000;
          const avgSpeedMbps = file.size / (1024 * 1024) / totalUploadTime;

          try {
            const result = JSON.parse(xhr.responseText);

            console.log(`🎉 Regular upload complete!`);
            console.log(`📈 Total time: ${totalUploadTime.toFixed(1)}s`);
            console.log(`📊 Average speed: ${avgSpeedMbps.toFixed(2)}MB/s`);

            handleUploadSuccess(result);
            resolve(result);
          } catch (parseError) {
            console.error(`❌ Error parsing response:`, parseError);
            reject(new Error("Invalid response format"));
          }
        } else {
          reject(new Error(`Upload failed with status: ${xhr.status}`));
        }
      });

      // Handle upload errors
      xhr.addEventListener("error", () => {
        const errorTime = Date.now();
        const timeBeforeError = (errorTime - uploadStartTime) / 1000;

        console.error(
          `❌ Regular upload error after ${timeBeforeError.toFixed(1)}s:`
        );
        console.error(`📋 Error details: Network error or request failed`);

        reject(new Error("Upload failed due to network error"));
      });

      // Handle upload abort
      xhr.addEventListener("abort", () => {
        console.log("Upload was cancelled");
        reject(new Error("Upload cancelled"));
      });

      // Set up abort controller
      uploadAbortController.current.signal.addEventListener("abort", () => {
        xhr.abort();
      });

      // Start the upload
      xhr.open(
        "POST",
        `https://api.cloudinary.com/v1_1/${CLOUDINARY_CLOUD_NAME}/auto/upload`
      );
      xhr.send(formData);
    }).catch((error) => {
      if (error.message === "Upload cancelled") {
        console.log("Upload was cancelled");
        return;
      }
      const errorTime = Date.now();
      const timeBeforeError = (errorTime - uploadStartTime) / 1000;

      console.error(
        `❌ Regular upload error after ${timeBeforeError.toFixed(1)}s:`
      );
      console.error(`📋 Error details:`, error);

      setFileUploading(false);
      setIsFinishing(false);
      setResolutionAcceptable(false);
      setResolutionWarning(
        "There was an error uploading your image. Please try again."
      );
      trackEvent("Upload: Regular Error", {
        error_message: error?.message || error?.toString() || "Unknown error",
        time_before_error: timeBeforeError,
      });
    });
  };

  // Network diagnostics
  const logNetworkInfo = () => {
    console.log(`🌐 Network diagnostics:`);

    if (navigator.connection) {
      const conn = navigator.connection;
      console.log(`📶 Connection type: ${conn.effectiveType || "unknown"}`);
      console.log(`⚡ Downlink: ${conn.downlink || "unknown"}Mbps`);
      console.log(`📈 RTT: ${conn.rtt || "unknown"}ms`);
      console.log(`💾 Data saver: ${conn.saveData ? "enabled" : "disabled"}`);
    } else {
      console.log(`📶 Connection API not supported`);
    }

    console.log(`🌍 User agent: ${navigator.userAgent}`);
    console.log(`🕒 Current time: ${new Date().toISOString()}`);
  };

  // Validate and upload file
  const processFile = async (file) => {
    // Reset state
    setPercentCompleted(0);
    setResolutionAcceptable(true);
    setResolutionWarning("");
    setFileUploading(true);
    setIsFinishing(false);
    setIsSaving(false);
    setCurrentFile(file);

    // Log network diagnostics
    logNetworkInfo();

    console.log(
      `📋 Upload config: Pro user: ${is_pro}, Max file size: ${MAX_FILE_SIZE_MB}MB`
    );

    // Check file size
    if (file.size > MAX_FILE_SIZE) {
      setFileUploading(false);
      setResolutionAcceptable(false);
      setResolutionWarning(
        `This file is too large. Please upload an image smaller than ${MAX_FILE_SIZE_MB}MB.`
      );
      trackEvent("Upload: File Size Error", {
        file_size: file.size,
      });
      return;
    }

    // Check if it's a TIFF file
    const fileName = file.name.toLowerCase();
    const isTiff = fileName.endsWith(".tiff") || fileName.endsWith(".tif");

    if (!isTiff) {
      // For non-TIFF files, check dimensions
      const img = new Image();
      const fileURL = URL.createObjectURL(file);
      img.src = fileURL;

      img.onload = async () => {
        const megapixels = (img.width * img.height) / 1000000;
        URL.revokeObjectURL(fileURL);

        if (megapixels > 200) {
          setFileUploading(false);
          setResolutionAcceptable(false);
          setResolutionWarning(
            "This image is over 200 megapixels. Please upload an image with a smaller resolution."
          );
          trackEvent("Upload: Max Resolution Error", {
            megapixels: megapixels,
          });
          return;
        }

        // Proceed with upload
        if (file.size > 100 * 1024 * 1024) {
          // 100MB
          await uploadFileChunked(file);
        } else {
          await uploadFileRegular(file);
        }
      };

      img.onerror = () => {
        URL.revokeObjectURL(fileURL);
        setFileUploading(false);
        setResolutionAcceptable(false);
        setResolutionWarning(
          "Unable to read image dimensions. Please try a different image."
        );
      };
    } else {
      // For TIFF files, skip dimension validation and proceed with upload
      if (file.size > 100 * 1024 * 1024) {
        // 100MB
        await uploadFileChunked(file);
      } else {
        await uploadFileRegular(file);
      }
    }
  };

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (uploadAbortController.current) {
        uploadAbortController.current.abort();
      }
    };
  }, []);

  const handleFileInput = (event) => {
    const files = event.target.files;
    if (files.length > 0) {
      const file = files[0];
      if (file.type.startsWith("image/")) {
        processFile(file);
      } else {
        setResolutionAcceptable(false);
        setResolutionWarning("Please select an image file.");
      }
    }
    // Clear the input so the same file can be selected again if needed
    event.target.value = "";
  };

  const handleDropzoneClick = () => {
    if (!fileUploading && !isSaving) {
      document.getElementById("upload-button").click();
    }
  };

  // Native drag event handlers as fallback
  const handleDragEnter = (e) => {
    e.preventDefault();
    e.stopPropagation();
    console.log("Native dragenter event");
    setIsDragOver(true);
  };

  const handleDragOver = (e) => {
    e.preventDefault();
    e.stopPropagation();
    console.log("Native dragover event");
    setIsDragOver(true);
  };

  const handleDragLeave = (e) => {
    e.preventDefault();
    e.stopPropagation();
    console.log("Native dragleave event");
    // Only set to false if we're actually leaving the dropzone area
    if (!e.currentTarget.contains(e.relatedTarget)) {
      setIsDragOver(false);
    }
  };

  const handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    console.log("Native drop event");
    setIsDragOver(false);

    const files = Array.from(e.dataTransfer.files);
    if (files.length > 0) {
      const file = files[0]; // Take only the first file
      if (file.type.startsWith("image/")) {
        processFile(file);
      } else {
        setResolutionAcceptable(false);
        setResolutionWarning("Please select an image file.");
      }
    }
  };

  const saveSuccess = (data) => {
    console.log("🎉 Upload Success Response:", data);
    console.log("📋 Response Structure:", JSON.stringify(data, null, 2));

    setFileUploading(false);
    setIsFinishing(false);
    setIsSaving(false);

    setResolutionAcceptable(true);
    console.log("✅ Resolution acceptable");

    // If we have a callback, use it instead of redirecting
    if (onUploadSuccess && typeof onUploadSuccess === "function") {
      console.log("🔄 Calling upload success callback");
      onUploadSuccess(data);
    } else {
      console.log("🔗 No callback provided, redirecting to:", data.url);
      window.location.href = data.url;
    }
  };

  const renderBlankState = () => {
    return (
      <div className="alert alert-warning mt-4 py-3">
        <h4 className="text-xl">Whoops 😕</h4>
        <span>{resolution_warning}</span>
        <p className="text-muted small mt-1">
          Please feel free to{" "}
          <a href="/pages/contact" className="underline">
            contact us
          </a>{" "}
          if for assistance.
        </p>
      </div>
    );
  };

  return (
    <div className="text-center w-full">
      <style>
        {`
          .uppy-DragDrop-label, .uppy-DragDrop-inner {
            display: none !important;
          }
          
          .animated-border {
            position: relative;
          }
          
          .border-svg {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
          }
          
          .border-rect {
            fill: none;
            stroke: #374151;
            stroke-width: 2px;
            vector-effect: non-scaling-stroke;
            stroke-dasharray: 8px;
            stroke-dashoffset: 16px;
            shape-rendering: geometricPrecision;
            transition: stroke 0.2s;
          }
          
          .animated-border:hover .border-rect {
            animation: marching-ants 0.5s linear infinite;
          }
          
          .animated-border.drag-over .border-rect {
            stroke: #3B82F6;
            animation: marching-ants 0.3s linear infinite;
          }
          
          .animated-border.uploading .border-rect {
            animation: marching-ants-reverse 1s linear infinite;
          }
          
          @keyframes marching-ants {
            to {
              stroke-dashoffset: 0;
            }
          }
          
          @keyframes marching-ants-reverse {
            from {
              stroke-dashoffset: 0;
            }
            to {
              stroke-dashoffset: 16px;
            }
          }
        `}
      </style>
      {!upload && (
        <div className="space-y-4">
          {/* Drag and Drop Zone */}
          <div
            ref={dropzoneRef}
            onClick={handleDropzoneClick}
            onDragEnter={handleDragEnter}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
            className={classNames(
              "animated-border p-6 md:p-12 transition-colors duration-200 cursor-pointer",
              isDragOver ? "drag-over bg-blue-50" : "",
              fileUploading && "pointer-events-none uploading"
            )}
            style={{
              position: "relative",
            }}
          >
            {/* SVG Border with Marching Ants */}
            <svg
              className="border-svg"
              viewBox="0 0 100 100"
              preserveAspectRatio="none"
            >
              <rect
                className="border-rect"
                x="1"
                y="1"
                width="98"
                height="98"
              />
            </svg>
            {(fileUploading || isFinishing) && !isSaving && (
              <div className="relative pt-1">
                <div className="flex mb-2 items-center justify-between">
                  <div>
                    {isFinishing ? (
                      <span className="inline-block font-medium pl-2 py-1 rounded-full text-gray-800 ">
                        <span className="">
                          <UploadPreloader />
                        </span>{" "}
                        Finishing
                      </span>
                    ) : (
                      <span className="inline-block font-medium py-1 rounded-full text-gray-800 animate-pulse">
                        Uploading...
                      </span>
                    )}
                  </div>
                  <div className="text-right">
                    <span
                      className={classNames(
                        percentCompleted === 100
                          ? "text-gray-800"
                          : "text-gray-800",
                        "inline-block font-medium"
                      )}
                    >
                      {percentCompleted}%
                    </span>
                  </div>
                </div>
                <div className="overflow-hidden h-2 mb-4 text-xs flex rounded bg-white">
                  <div
                    style={{ width: `${percentCompleted}%` }}
                    className={classNames(
                      percentCompleted === 100 ? "bg-gray-900" : "bg-gray-900",
                      "shadow-none flex flex-col text-center whitespace-nowrap text-white justify-center "
                    )}
                  ></div>
                </div>
              </div>
            )}

            <div className="flex flex-col items-center space-y-4">
              {!isSaving && !fileUploading && (
                <div className="w-12 h-12 bg-gray-900 rounded-full flex items-center justify-center">
                  <svg
                    className="w-6 h-6 text-white"
                    width="25"
                    height="25"
                    viewBox="0 0 25 25"
                    fill="none"
                    xmlns="http://www.w3.org/2000/svg"
                  >
                    <g clipPath="url(#clip0_5194_1336)">
                      <path
                        d="M22.661 16.5586V21.6433C22.661 21.913 22.5538 22.1717 22.3631 22.3624C22.1724 22.5531 21.9137 22.6603 21.644 22.6603H3.33893C3.06922 22.6603 2.81056 22.5531 2.61984 22.3624C2.42913 22.1717 2.32198 21.913 2.32198 21.6433V16.5586H0.288086V21.6433C0.288086 22.4525 0.609514 23.2285 1.18166 23.8006C1.7538 24.3727 2.5298 24.6942 3.33893 24.6942H21.644C22.4532 24.6942 23.2291 24.3727 23.8013 23.8006C24.3734 23.2285 24.6949 22.4525 24.6949 21.6433V16.5586H22.661Z"
                        fill="white"
                      />
                      <path
                        d="M12.4578 0.288098C12.0574 0.286994 11.6606 0.364935 11.2903 0.517455C10.92 0.669975 10.5834 0.894075 10.2999 1.17691L6.31445 5.16233L7.75242 6.6003L11.448 2.90572L11.4745 19.6101H13.5084L13.4819 2.91996L17.1622 6.6003L18.6002 5.16233L14.6148 1.17691C14.3314 0.894106 13.9951 0.670017 13.6249 0.517495C13.2548 0.364972 12.8582 0.287016 12.4578 0.288098V0.288098Z"
                        fill="white"
                      />
                    </g>
                    <defs>
                      <clipPath id="clip0_5194_1336">
                        <rect
                          width="24.4068"
                          height="24.4068"
                          fill="white"
                          transform="translate(0.288086 0.288086)"
                        />
                      </clipPath>
                    </defs>
                  </svg>
                </div>
              )}

              <div className="text-center text-lg font-medium text-gray-900">
                {isSaving ? (
                  <p className="mb-0">
                    <UploadPreloader />
                    Storing your image
                  </p>
                ) : (
                  !fileUploading && (
                    <>
                      {isMobile ? (
                        <>
                          <p className="mb-0">Choose a file</p>
                        </>
                      ) : (
                        <>
                          <p className="mb-0">
                            Drag your image here{" "}
                            <span className="text-xs">
                              (max {MAX_FILE_SIZE_MB}MB)
                            </span>
                          </p>
                          <p className="mb-0">
                            or{" "}
                            <span className="underline cursor-pointer">
                              browse for a file
                            </span>
                          </p>
                        </>
                      )}
                    </>
                  )
                )}
              </div>
            </div>
          </div>

          {/* Hidden file input for fallback */}
          <input
            className="hidden"
            type="file"
            id="upload-button"
            accept="image/*"
            onChange={handleFileInput}
          />
        </div>
      )}

      {!resolution_acceptable && renderBlankState()}
    </div>
  );
};

const UploadPreloader = () => (
  <svg
    className="inline animate-spin -ml-1 mr-1 h-4 w-4 text-gray-800"
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
  >
    <circle
      className="opacity-25"
      cx="12"
      cy="12"
      r="10"
      stroke="currentColor"
      strokeWidth="4"
    ></circle>
    <path
      className="opacity-75"
      fill="currentColor"
      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
    ></path>
  </svg>
);

export default Uploader;
