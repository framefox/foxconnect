import React, { useEffect } from "react";
import { SvgIcon } from "../components";

function VideoLightbox({ isOpen, embedId, title, onClose }) {
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

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/90 p-4"
      onClick={onClose}
    >
      {/* Close button */}
      <div className="absolute top-4 right-4 z-10">
        <button
          onClick={onClose}
          className="text-white hover:text-gray-300 transition-colors"
          aria-label="Close video"
        >
          <SvgIcon name="XIcon" className="w-8 h-8" />
        </button>
      </div>

      {/* Video container */}
      <div
        className="relative w-full max-w-7xl"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Optional title */}
        {title && (
          <div className="text-white text-center mb-4 text-lg font-semibold">
            {title}
          </div>
        )}

        {/* Loom embed container with 16:9 aspect ratio */}
        <div
          style={{ position: "relative", paddingBottom: "56.25%", height: 0 }}
        >
          <iframe
            src={`https://www.loom.com/embed/${embedId}?autoplay=1`}
            frameBorder="0"
            webkitallowfullscreen="true"
            mozallowfullscreen="true"
            allowFullScreen
            style={{
              position: "absolute",
              top: 0,
              left: 0,
              width: "100%",
              height: "100%",
            }}
            title={title || "Video"}
          ></iframe>
        </div>
      </div>
    </div>
  );
}

export default VideoLightbox;
