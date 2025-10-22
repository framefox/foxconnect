import React, { useEffect, useState } from "react";

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

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/90 p-4"
      onClick={onClose}
    >
      {/* Close button */}
      <button
        onClick={onClose}
        className="absolute top-4 right-4 text-white hover:text-gray-300 transition-colors z-10"
        aria-label="Close lightbox"
      >
        <i className="fa-solid fa-xmark text-3xl"></i>
      </button>

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
