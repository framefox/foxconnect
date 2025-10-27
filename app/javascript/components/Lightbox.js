import React, { useEffect, useState } from "react";
import axios from "axios";
import { SvgIcon } from "../components";

function Lightbox({ isOpen, imageUrl, thumbnailUrl, imageAlt, onClose }) {
  const [largeImageLoaded, setLargeImageLoaded] = useState(false);

  // Handle ESC key to close
  useEffect(() => {
    const handleEsc = (event) => {
      if (event.key === "Escape") {
        onClose();
      }
    };

    if (isOpen) {
      document.addEventListener("keydown", handleEsc);
      // Prevent body scroll when lightbox is open
      document.body.style.overflow = "hidden";
    }

    return () => {
      document.removeEventListener("keydown", handleEsc);
      document.body.style.overflow = "unset";
    };
  }, [isOpen, onClose]);

  // Reset loading state when lightbox opens/closes
  useEffect(() => {
    if (isOpen) {
      setLargeImageLoaded(false);
    }
  }, [isOpen, imageUrl]);

  const handleDownload = async (e) => {
    e.stopPropagation(); // Prevent closing the lightbox
    try {
      const response = await axios.get(imageUrl, {
        responseType: "blob",
      });
      const url = window.URL.createObjectURL(response.data);
      const link = document.createElement("a");
      link.href = url;
      link.download = imageAlt || "image.jpg";
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);
    } catch (error) {
      console.error("Error downloading image:", error);
    }
  };

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/90 p-4"
      onClick={onClose}
    >
      {/* Action buttons */}
      <div className="absolute top-4 right-4 flex items-center space-x-3 z-10">
        {/* Download button */}
        <button
          onClick={handleDownload}
          className="text-white hover:text-gray-300 transition-colors"
          aria-label="Download image"
        >
          <SvgIcon name="SaveIcon" className="w-7 h-7" />
        </button>

        {/* Close button */}
        <button
          onClick={onClose}
          className="text-white hover:text-gray-300 transition-colors"
          aria-label="Close lightbox"
        >
          <SvgIcon name="XIcon" className="w-8 h-8" />
        </button>
      </div>

      {/* Image container */}
      <div
        className="relative max-w-7xl max-h-full flex items-center justify-center"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Blurred thumbnail placeholder - fills the image area */}
        {thumbnailUrl && !largeImageLoaded && (
          <img
            src={thumbnailUrl}
            alt={imageAlt}
            className="max-w-full max-h-[90vh] object-cover blur-xl scale-110"
          />
        )}

        {/* Loading spinner overlay */}
        {!largeImageLoaded && (
          <div className="absolute inset-0 flex items-center justify-center">
            <i className="fa-solid fa-spinner-third fa-spin text-white text-4xl"></i>
          </div>
        )}

        {/* Large image - hidden until loaded */}
        <img
          src={imageUrl}
          alt={imageAlt}
          className={`max-w-full max-h-[90vh] object-contain transition-opacity duration-300 ${
            largeImageLoaded ? "opacity-100" : "opacity-0 absolute"
          }`}
          onLoad={() => setLargeImageLoaded(true)}
        />
      </div>
    </div>
  );
}

export default Lightbox;
