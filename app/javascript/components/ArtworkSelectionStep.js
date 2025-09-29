import React, { useState } from "react";
import Uploader from "./Uploader";

function ArtworkSelectionStep({
  selectedProduct,
  loading,
  error,
  artworks,
  onArtworkSelect,
  onRetry,
  onUploadSuccess,
}) {
  const [showUploader, setShowUploader] = useState(false);

  // Helper function to format cents to dollars
  const formatCentsToPrice = (cents) => {
    if (!cents && cents !== 0) return "N/A";
    return `$${(cents / 100).toFixed(2)}`;
  };

  const handleUploadSuccess = (uploadData) => {
    console.log("📤 Upload completed in ArtworkSelectionStep:", uploadData);

    // Hide the uploader
    setShowUploader(false);

    // Call parent callback to refresh artwork list
    if (onUploadSuccess) {
      onUploadSuccess(uploadData);
    }
  };
  return (
    <>
      {/* Selected Product Summary */}
      {selectedProduct && (
        <div className="mb-6 bg-slate-50 border border-slate-200 rounded-lg p-4">
          <div className="flex items-center space-x-4">
            {selectedProduct.preview_image && (
              <img
                src={selectedProduct.preview_image}
                alt={selectedProduct.description}
                className="h-16 w-16 object-contain rounded-md"
              />
            )}
            <div>
              <h3 className="text-lg font-medium text-gray-900">
                {selectedProduct.code}
              </h3>
              <p className="text-sm text-gray-600">
                {selectedProduct.description}
              </p>
              <p className="text-sm font-medium text-blue-600">
                {formatCentsToPrice(selectedProduct.cost_cents)}
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Upload New Artwork */}
      <div className="mb-6">
        {!showUploader ? (
          <button
            onClick={() => setShowUploader(true)}
            className="inline-flex items-center px-4 py-2 bg-slate-100 text-slate-900 hover:bg-slate-200 rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
          >
            <svg
              className="w-4 h-4 mr-2"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth="2"
                d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
              />
            </svg>
            Upload a new file
          </button>
        ) : (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">
                Upload your image file
              </span>
              <button
                onClick={() => setShowUploader(false)}
                className="text-gray-400 hover:text-gray-600 transition-colors"
              >
                <svg
                  className="w-5 h-5"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            </div>
            <Uploader
              post_image_url="https://shop.framefox.co.nz/api/shopify-customers/7315072254051/images?auth=0936ac0193ec48f7f88d38c1518572a2e5f8a5c3"
              shopify_customer_id={7315072254051}
              is_pro={true}
              onUploadSuccess={handleUploadSuccess}
            />
          </div>
        )}
      </div>

      {/* Divider */}
      <div className="mb-6">
        <div className="relative">
          <div className="absolute inset-0 flex items-center">
            <div className="w-full border-t border-gray-300" />
          </div>
          <div className="relative flex justify-center text-sm">
            <span className="px-2 bg-white text-gray-500">
              Choose an existing upload.
            </span>
          </div>
        </div>
      </div>

      {loading && (
        <div className="flex items-center justify-center py-8">
          <i className="fa-solid fa-spinner-third fa-spin text-blue-600 text-2xl"></i>
          <span className="ml-3 text-gray-600">Loading artworks...</span>
        </div>
      )}

      {error && (
        <div className="text-center py-8">
          <div className="text-red-600 mb-2">{error}</div>
          <button
            onClick={onRetry}
            className="px-4 py-2 bg-slate-900 text-slate-50 hover:bg-slate-800 rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
          >
            Try Again
          </button>
        </div>
      )}

      {!loading && !error && artworks.length === 0 && (
        <div className="text-center py-8 text-gray-500">
          No artworks available
        </div>
      )}

      {!loading && !error && artworks.length > 0 && (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {artworks.map((artwork) => (
            <div
              key={artwork.id}
              className="group relative bg-white border border-gray-200 rounded-lg overflow-hidden  hover:shadow-md transition-shadow cursor-pointer"
              onClick={() => onArtworkSelect(artwork)}
            >
              <div className="flex">
                {/* Image section */}
                <div className="w-24 h-24 flex-shrink-0 bg-gray-50 flex items-center justify-center rounded-l-lg">
                  <img
                    src={artwork.url}
                    alt={artwork.filename}
                    className="w-full h-full object-contain"
                  />
                </div>

                {/* Details section */}
                <div className="flex-1 p-4">
                  <div className="space-y-3">
                    <div>
                      <p className="text-sm font-semibold text-slate-900 truncate">
                        {artwork.filename}
                      </p>
                      <p className="text-xs text-slate-500 mt-1">
                        ID: {artwork.id} | Key: {artwork.key}
                      </p>
                      <span className="text-slate-600 text-xs">
                        {artwork.width} × {artwork.height}px
                      </span>
                    </div>
                  </div>
                </div>

                {/* Select button */}
                <div className="p-4 flex items-center">
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      onArtworkSelect(artwork);
                    }}
                    className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-slate-50 bg-slate-900 hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-950 transition-colors"
                  >
                    Select
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  );
}

export default ArtworkSelectionStep;
