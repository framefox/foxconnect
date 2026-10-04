import React, { useState, useEffect, useRef } from "react";
import axios from "axios";
import classNames from "classnames";
import { isMobile } from "react-device-detect";

// Cloudinary configuration
const CLOUDINARY_CLOUD_NAME = "framefox";
const CLOUDINARY_UPLOAD_PRESET = "framefox_default";
const CHUNK_SIZE = 10 * 1024 * 1024; // 10MB chunks

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

const MultiUploader = ({
  post_image_url,
  shopify_customer_id,
  is_pro = false,
  onFileSaved,
}) => {
  const [files, setFiles] = useState([]);
  const [isDragOver, setIsDragOver] = useState(false);
  const [isUploading, setIsUploading] = useState(false);

  const MAX_FILE_SIZE = is_pro ? 200 * 1024 * 1024 : 100 * 1024 * 1024;
  const MAX_FILE_SIZE_MB = Math.round(MAX_FILE_SIZE / (1024 * 1024));

  const uploadAbortControllers = useRef({});
  const dropzoneRef = useRef(null);
  const fileInputRef = useRef(null);

  const addFiles = (newFiles) => {
    const filesWithMetadata = Array.from(newFiles).map((file, index) => {
      let error = null;

      if (!file.type.startsWith("image/")) {
        error = "Please select an image file.";
      } else if (file.size > MAX_FILE_SIZE) {
        error = `This file is too large. Please upload an image smaller than ${MAX_FILE_SIZE_MB}MB.`;
        trackEvent("Upload: File Size Error", { file_size: file.size });
      }

      return {
        id: `${Date.now()}-${index}-${Math.random().toString(36).slice(2, 9)}`,
        file,
        name: file.name,
        size: file.size,
        status: error ? "error" : "pending",
        progress: 0,
        error,
        isFinishing: false,
        isSaving: false,
      };
    });

    setFiles((prev) => [...prev, ...filesWithMetadata]);
  };

  const updateFileStatus = (fileId, updates) => {
    setFiles((prev) =>
      prev.map((f) => (f.id === fileId ? { ...f, ...updates } : f))
    );
  };

  const removeFile = (fileId) => {
    const controller = uploadAbortControllers.current[fileId];
    if (controller) {
      controller.abort();
      delete uploadAbortControllers.current[fileId];
    }
    setFiles((prev) => prev.filter((f) => f.id !== fileId));
  };

  const generateUniqueUploadId = () => {
    return `uqid-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
  };

  const handleUploadSuccess = async (fileId, result) => {
    updateFileStatus(fileId, {
      isFinishing: true,
      progress: 100,
    });

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

    if (result.coordinates != null) {
      image.cx = result.coordinates.custom[0][0];
      image.cy = result.coordinates.custom[0][1];
      image.cw = result.coordinates.custom[0][2];
      image.ch = result.coordinates.custom[0][3];
    }

    updateFileStatus(fileId, { isSaving: true });

    try {
      const apiAuthToken = window.FramefoxConfig?.apiAuthToken;
      const response = await axios.post(
        post_image_url,
        { image },
        {
          params: apiAuthToken ? { auth: apiAuthToken } : {},
        }
      );
      updateFileStatus(fileId, {
        status: "completed",
        isFinishing: false,
        isSaving: false,
      });
      if (onFileSaved) onFileSaved(response.data);
    } catch (error) {
      console.error("Error saving image:", error);
      updateFileStatus(fileId, {
        status: "error",
        error: "There was an error saving your image. Please try again.",
        isFinishing: false,
        isSaving: false,
      });
    }
  };

  const uploadFileChunked = async (fileId, file) => {
    const uniqueUploadId = generateUniqueUploadId();
    const totalChunks = Math.ceil(file.size / CHUNK_SIZE);
    let currentChunk = 0;
    const uploadStartTime = Date.now();
    let totalBytesUploaded = 0;

    const abortController = new AbortController();
    uploadAbortControllers.current[fileId] = abortController;

    const uploadChunk = async (start, end) => {
      const chunkSize = end - start;
      const formData = new FormData();
      formData.append("file", file.slice(start, end));
      formData.append("cloud_name", CLOUDINARY_CLOUD_NAME);
      formData.append("upload_preset", CLOUDINARY_UPLOAD_PRESET);
      const contentRange = `bytes ${start}-${end - 1}/${file.size}`;

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
            signal: abortController.signal,
          }
        );

        if (!response.ok) {
          throw new Error(
            `Chunk upload failed with status: ${response.status}`
          );
        }

        totalBytesUploaded += chunkSize;
        currentChunk++;

        const uploadProgress = Math.min(
          100,
          (totalBytesUploaded / file.size) * 100
        );
        updateFileStatus(fileId, { progress: Math.round(uploadProgress) });

        if (currentChunk < totalChunks) {
          const nextStart = currentChunk * CHUNK_SIZE;
          const nextEnd = Math.min(nextStart + CHUNK_SIZE, file.size);
          await uploadChunk(nextStart, nextEnd);
        } else {
          const result = await response.json();
          await handleUploadSuccess(fileId, result);
        }
      } catch (error) {
        if (error.name === "AbortError") return;
        console.error("Error uploading chunk:", error);
        updateFileStatus(fileId, {
          status: "error",
          error: "There was an error uploading your image. Please try again.",
        });
        trackEvent("Upload: Chunked Error", {
          error_message: error?.message || error?.toString() || "Unknown error",
          chunk: currentChunk,
          total_chunks: totalChunks,
          time_before_error: (Date.now() - uploadStartTime) / 1000,
        });
      }
    };

    const start = 0;
    const end = Math.min(CHUNK_SIZE, file.size);
    await uploadChunk(start, end);
  };

  const uploadFileRegular = (fileId, file) => {
    const uploadStartTime = Date.now();
    const formData = new FormData();
    formData.append("file", file);
    formData.append("cloud_name", CLOUDINARY_CLOUD_NAME);
    formData.append("upload_preset", CLOUDINARY_UPLOAD_PRESET);

    const abortController = new AbortController();
    uploadAbortControllers.current[fileId] = abortController;

    return new Promise((resolve) => {
      const xhr = new XMLHttpRequest();

      xhr.upload.addEventListener("progress", (event) => {
        if (event.lengthComputable) {
          const uploadProgress = (event.loaded / event.total) * 100;
          updateFileStatus(fileId, { progress: Math.round(uploadProgress) });
        }
      });

      xhr.addEventListener("load", async () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          try {
            const result = JSON.parse(xhr.responseText);
            await handleUploadSuccess(fileId, result);
          } catch (parseError) {
            console.error("Error parsing response:", parseError);
            updateFileStatus(fileId, {
              status: "error",
              error: "There was an error uploading your image. Please try again.",
            });
          }
        } else {
          updateFileStatus(fileId, {
            status: "error",
            error: "There was an error uploading your image. Please try again.",
          });
          trackEvent("Upload: Regular Error", {
            error_message: `Upload failed with status: ${xhr.status}`,
            time_before_error: (Date.now() - uploadStartTime) / 1000,
          });
        }
        resolve();
      });

      xhr.addEventListener("error", () => {
        updateFileStatus(fileId, {
          status: "error",
          error: "There was an error uploading your image. Please try again.",
        });
        trackEvent("Upload: Regular Error", {
          error_message: "Upload failed due to network error",
          time_before_error: (Date.now() - uploadStartTime) / 1000,
        });
        resolve();
      });

      xhr.addEventListener("abort", () => {
        resolve();
      });

      abortController.signal.addEventListener("abort", () => {
        xhr.abort();
      });

      xhr.open(
        "POST",
        `https://api.cloudinary.com/v1_1/${CLOUDINARY_CLOUD_NAME}/auto/upload`
      );
      xhr.send(formData);
    });
  };

  const uploadFile = (fileId, file) => {
    if (file.size > 100 * 1024 * 1024) {
      return uploadFileChunked(fileId, file);
    }
    return uploadFileRegular(fileId, file);
  };

  const checkDimensions = (file) =>
    new Promise((resolve) => {
      const fileName = file.name.toLowerCase();
      const isTiff = fileName.endsWith(".tiff") || fileName.endsWith(".tif");
      if (isTiff) {
        resolve(null);
        return;
      }

      const img = new Image();
      const fileURL = URL.createObjectURL(file);
      img.onload = () => {
        const megapixels = (img.width * img.height) / 1000000;
        URL.revokeObjectURL(fileURL);
        if (megapixels > 200) {
          trackEvent("Upload: Max Resolution Error", { megapixels });
          resolve(
            "This image is over 200 megapixels. Please upload an image with a smaller resolution."
          );
          return;
        }
        resolve(null);
      };
      img.onerror = () => {
        URL.revokeObjectURL(fileURL);
        resolve(
          "Unable to read image dimensions. Please try a different image."
        );
      };
      img.src = fileURL;
    });

  const processFile = async (fileData) => {
    const { id, file } = fileData;
    updateFileStatus(id, { status: "uploading", error: null });

    const dimensionError = await checkDimensions(file);
    if (dimensionError) {
      updateFileStatus(id, { status: "error", error: dimensionError });
      return;
    }

    await uploadFile(id, file);
  };

  const uploadAllFiles = async () => {
    const pendingFiles = files.filter((f) => f.status === "pending");
    if (pendingFiles.length === 0) return;

    setIsUploading(true);
    for (const fileData of pendingFiles) {
      await processFile(fileData);
    }
    setIsUploading(false);
  };

  const handleFileInput = (event) => {
    const selectedFiles = event.target.files;
    if (selectedFiles.length > 0) {
      addFiles(selectedFiles);
    }
    event.target.value = "";
  };

  const handleDropzoneClick = () => {
    if (!isUploading) {
      fileInputRef.current?.click();
    }
  };

  const handleDragEnter = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragOver(true);
  };

  const handleDragOver = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragOver(true);
  };

  const handleDragLeave = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (!e.currentTarget.contains(e.relatedTarget)) {
      setIsDragOver(false);
    }
  };

  const handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragOver(false);

    const droppedFiles = Array.from(e.dataTransfer.files);
    if (droppedFiles.length > 0) {
      addFiles(droppedFiles);
    }
  };

  useEffect(() => {
    const controllers = uploadAbortControllers.current;
    return () => {
      Object.values(controllers).forEach((controller) => {
        if (controller) controller.abort();
      });
    };
  }, []);

  const statusCounts = files.reduce((acc, file) => {
    acc[file.status] = (acc[file.status] || 0) + 1;
    return acc;
  }, {});

  const formatFileSize = (bytes) => {
    if (bytes === 0) return "0 Bytes";
    const k = 1024;
    const sizes = ["Bytes", "KB", "MB", "GB"];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i];
  };

  const hasPending = files.some((f) => f.status === "pending");

  return (
    <div className="text-center w-full space-y-6">
      <style>
        {`
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
          isUploading && "pointer-events-none uploading"
        )}
      >
        <svg
          className="border-svg"
          viewBox="0 0 100 100"
          preserveAspectRatio="none"
        >
          <rect className="border-rect" x="1" y="1" width="98" height="98" />
        </svg>

        <div className="flex flex-col items-center space-y-4">
          <div className="w-12 h-12 bg-gray-900 rounded-full flex items-center justify-center">
            <svg
              className="w-6 h-6 text-white"
              width="25"
              height="25"
              viewBox="0 0 25 25"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <g clipPath="url(#clip0_multi_upload)">
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
                <clipPath id="clip0_multi_upload">
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

          <div className="text-center text-lg font-medium text-gray-900">
            {isMobile ? (
              <p className="mb-0">Choose files</p>
            ) : (
              <>
                <p className="mb-0">
                  Drag your images here{" "}
                  <span className="text-xs">(max {MAX_FILE_SIZE_MB}MB each)</span>
                </p>
                <p className="mb-0">
                  or{" "}
                  <span className="underline cursor-pointer">
                    browse for files
                  </span>
                </p>
              </>
            )}
          </div>
        </div>
      </div>

      <input
        ref={fileInputRef}
        className="hidden"
        type="file"
        accept="image/*"
        multiple
        onChange={handleFileInput}
      />

      {files.length > 0 && (
        <div className="space-y-4 text-left">
          <div className="flex justify-between items-center gap-4">
            <h3 className="text-lg font-medium text-slate-900">
              {files.length} file{files.length !== 1 ? "s" : ""} selected
            </h3>
            {hasPending && (
              <button
                type="button"
                onClick={uploadAllFiles}
                disabled={isUploading}
                className="inline-flex items-center px-4 py-2.5 bg-slate-900 text-white hover:bg-slate-800 rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 disabled:opacity-50"
              >
                {isUploading ? "Uploading..." : "Upload All"}
              </button>
            )}
          </div>

          {Object.keys(statusCounts).length > 0 && (
            <div className="text-sm text-gray-600 flex flex-wrap gap-x-4 gap-y-1">
              {statusCounts.pending ? (
                <span>Pending: {statusCounts.pending}</span>
              ) : null}
              {statusCounts.uploading ? (
                <span>Uploading: {statusCounts.uploading}</span>
              ) : null}
              {statusCounts.completed ? (
                <span className="text-green-600">
                  Completed: {statusCounts.completed}
                </span>
              ) : null}
              {statusCounts.error ? (
                <span className="text-red-600">Errors: {statusCounts.error}</span>
              ) : null}
            </div>
          )}

          <div className="space-y-2 max-h-96 overflow-y-auto">
            {files.map((fileData) => (
              <div
                key={fileData.id}
                className="flex items-center justify-between p-3 border border-gray-200 rounded-lg bg-gray-50"
              >
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-3">
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-900 truncate">
                        {fileData.name}
                      </p>
                      <p className="text-xs text-gray-500">
                        {formatFileSize(fileData.size)}
                      </p>
                    </div>

                    <div className="flex items-center gap-2 flex-shrink-0">
                      {fileData.status === "pending" && (
                        <span className="text-xs text-gray-500">Ready</span>
                      )}
                      {fileData.status === "uploading" && (
                        <div className="flex items-center gap-2">
                          <span className="text-xs text-slate-700">
                            {fileData.isSaving
                              ? "Saving..."
                              : fileData.isFinishing
                                ? "Finishing..."
                                : `${fileData.progress}%`}
                          </span>
                          <div className="w-16 bg-gray-200 rounded-full h-1.5">
                            <div
                              className="bg-slate-900 h-1.5 rounded-full transition-all duration-300"
                              style={{ width: `${fileData.progress}%` }}
                            />
                          </div>
                        </div>
                      )}
                      {fileData.status === "completed" && (
                        <span className="text-xs text-green-600">Complete</span>
                      )}
                      {fileData.status === "error" && (
                        <span className="text-xs text-red-600">Error</span>
                      )}

                      {(fileData.status === "pending" ||
                        fileData.status === "error") && (
                        <button
                          type="button"
                          onClick={() => removeFile(fileData.id)}
                          className="text-sm text-red-600 hover:text-red-800"
                        >
                          Remove
                        </button>
                      )}
                    </div>
                  </div>

                  {fileData.error && (
                    <p className="text-xs text-red-600 mt-1">{fileData.error}</p>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

export default MultiUploader;
