import React, { useState } from "react";
import Uploader from "./Uploader";
import { SvgIcon } from "../components";
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
  const [searchTerm, setSearchTerm] = useState("");

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

  // Filter artworks based on search term
  const filteredArtworks = artworks.filter((artwork) =>
    artwork.filename.toLowerCase().includes(searchTerm.toLowerCase())
  );
  return (
    <div className="flex flex-col h-full overflow-hidden">
      {/* Fixed header section - Selected Product Summary */}
      <div className="flex-shrink-0">
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
                  {selectedProduct.description}
                </h3>
                <p className="text-sm text-gray-600">{selectedProduct.title}</p>
              </div>
            </div>
          </div>
        )}

        {/* Upload New Artwork and Search Bar */}
        <div className="mb-6 flex items-center justify-between gap-4">
          <div className="flex-shrink-0">
            {!showUploader ? (
              <button
                onClick={() => setShowUploader(true)}
                className="inline-flex items-center px-4 py-3 bg-slate-900 text-white hover:bg-slate-800 rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
              >
                <SvgIcon name="UploadIcon" className="w-4 h-4 mr-2" />
                Upload a new file
              </button>
            ) : (
              <button
                onClick={() => setShowUploader(false)}
                className="inline-flex items-center px-4 py-3 bg-slate-100 text-slate-700 hover:bg-slate-200 rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
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
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
                Cancel Upload
              </button>
            )}
          </div>

          {/* Search Bar */}
          <div className="flex-1 max-w-md">
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <svg
                  className="h-5 w-5 text-gray-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                  />
                </svg>
              </div>
              <input
                type="text"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                placeholder="Search artworks by filename..."
                className="block w-full pl-10 pr-3 py-2.5 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-2 focus:ring-slate-950 focus:border-slate-950 text-sm"
              />
              {searchTerm && (
                <button
                  onClick={() => setSearchTerm("")}
                  className="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600"
                >
                  <svg
                    className="h-4 w-4"
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
              )}
            </div>
          </div>
        </div>

        {/* Uploader Component */}
        {showUploader && (
          <div className="mb-6">
            <Uploader
              post_image_url="http://dev.framefox.co.nz:3001/api/shopify-customers/7315072254051/images?auth=0936ac0193ec48f7f88d38c1518572a2e5f8a5c3"
              shopify_customer_id={7315072254051}
              is_pro={true}
              onUploadSuccess={handleUploadSuccess}
            />
          </div>
        )}

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
      </div>

      {/* Scrollable content area */}
      <div className="flex-1 min-h-0 overflow-y-auto">
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

        {!loading &&
          !error &&
          artworks.length > 0 &&
          filteredArtworks.length === 0 && (
            <div className="text-center py-8 text-gray-500">
              No artworks found matching "{searchTerm}"
            </div>
          )}

        {!loading && !error && filteredArtworks.length > 0 && (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 pb-4">
            {filteredArtworks.map((artwork) => (
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
      </div>
    </div>
  );
}

export default ArtworkSelectionStep;
