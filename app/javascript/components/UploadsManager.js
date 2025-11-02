import React, { useState, useEffect } from "react";
import axios from "axios";
import Uploader from "./Uploader";
import ImagePreviewModal from "./ImagePreviewModal";
import SvgIcon from "./SvgIcon";

function UploadsManager() {
  const [showUploader, setShowUploader] = useState(false);
  const [searchTerm, setSearchTerm] = useState("");
  const [artworks, setArtworks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [previewImage, setPreviewImage] = useState(null);

  useEffect(() => {
    fetchArtworks();
  }, []);

  const fetchArtworks = async () => {
    setLoading(true);
    setError(null);
    try {
      // Validate configuration exists
      if (
        !window.FramefoxConfig ||
        !window.FramefoxConfig.apiUrl ||
        !window.FramefoxConfig.shopifyCustomerId
      ) {
        console.error(
          "FramefoxConfig not available or missing shopifyCustomerId"
        );
        setError("Configuration error. Please refresh the page.");
        setLoading(false);
        return;
      }

      const response = await axios.get(
        `${window.FramefoxConfig.apiUrl}/shopify-customers/${window.FramefoxConfig.shopifyCustomerId}/images.json`
      );
      setArtworks(response.data.images);
    } catch (err) {
      setError("Failed to load artworks. Please try again.");
      console.error("Error fetching artworks:", err);
    } finally {
      setLoading(false);
    }
  };

  const handleUploadSuccess = (uploadData) => {
    console.log("📤 Upload completed in UploadsManager:", uploadData);

    // Hide the uploader
    setShowUploader(false);

    // Refresh artwork list
    fetchArtworks();
  };

  const handleImageClick = (artwork) => {
    setPreviewImage(artwork);
  };

  const handleClosePreview = () => {
    setPreviewImage(null);
  };

  const handleDeleteClick = async (artwork, e) => {
    e.stopPropagation();

    if (
      !confirm(
        `Are you sure you want to delete "${
          artwork.title || artwork.filename
        }"?`
      )
    ) {
      return;
    }

    try {
      // Validate configuration exists
      if (
        !window.FramefoxConfig ||
        !window.FramefoxConfig.apiUrl ||
        !window.FramefoxConfig.shopifyCustomerId
      ) {
        console.error(
          "FramefoxConfig not available or missing shopifyCustomerId"
        );
        alert("Configuration error. Please refresh the page.");
        return;
      }

      await axios.delete(
        `${window.FramefoxConfig.apiUrl}/shopify-customers/${window.FramefoxConfig.shopifyCustomerId}/images/${artwork.id}/soft_delete.json`
      );

      // Refresh the artworks list after successful deletion
      fetchArtworks();
    } catch (err) {
      console.error("Error deleting artwork:", err);
      alert("Failed to delete artwork. Please try again.");
    }
  };

  // Filter artworks based on search term
  const filteredArtworks = artworks.filter((artwork) =>
    (artwork.title || artwork.filename || "")
      .toLowerCase()
      .includes(searchTerm.toLowerCase())
  );

  return (
    <div className="flex flex-col h-full overflow-hidden">
      {/* Fixed header section */}
      <div className="flex-shrink-0">
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
                placeholder="Search artworks by title..."
                className="block w-full pl-10 pr-3 py-2.5 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-2 focus:ring-slate-950 focus:border-slate-950 text-sm"
              />
              {searchTerm && (
                <button
                  onClick={() => setSearchTerm("")}
                  className="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600"
                >
                  <SvgIcon name="SearchIcon" className="w-4 h-4" />
                </button>
              )}
            </div>
          </div>
        </div>

        {/* Uploader Component */}
        {showUploader && (
          <div className="mb-6">
            <Uploader
              post_image_url={
                window.FramefoxConfig
                  ? `${window.FramefoxConfig.apiUrl}/shopify-customers/${window.FramefoxConfig.shopifyCustomerId}/images`
                  : ""
              }
              shopify_customer_id={window.FramefoxConfig?.shopifyCustomerId}
              is_pro={true}
              onUploadSuccess={handleUploadSuccess}
            />
          </div>
        )}

        {/* Divider */}
        {!showUploader && artworks.length > 0 && (
          <div className="mb-6">
            <div className="relative">
              <div className="absolute inset-0 flex items-center">
                <div className="w-full border-t border-gray-300" />
              </div>
              <div className="relative flex justify-center text-sm">
                <span className="px-2 bg-white text-gray-500">
                  Your uploaded images
                </span>
              </div>
            </div>
          </div>
        )}
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
              onClick={fetchArtworks}
              className="px-4 py-2 bg-slate-900 text-slate-50 hover:bg-slate-800 rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
            >
              Try Again
            </button>
          </div>
        )}

        {!loading && !error && artworks.length === 0 && (
          <div className="text-center py-8 text-gray-500">
            No artworks available. Upload your first image to get started.
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
                className="group relative bg-white border border-gray-200 rounded-lg overflow-hidden hover:shadow-md transition-shadow cursor-pointer"
                onClick={() => handleImageClick(artwork)}
              >
                <div className="flex">
                  {/* Image section */}
                  <div className="w-24 h-24 flex-shrink-0 bg-gray-50 flex items-center justify-center rounded-l-lg">
                    <img
                      src={artwork.thumb || artwork.url}
                      alt={artwork.title || artwork.filename}
                      className="w-full h-full object-contain"
                    />
                  </div>

                  {/* Details section */}
                  <div className="flex-1 p-4">
                    <div className="space-y-2">
                      <div>
                        <p className="text-sm font-semibold text-slate-900 break-words">
                          {artwork.title || artwork.filename}
                        </p>
                        <span className="text-slate-600 text-xs">
                          {artwork.width && artwork.height
                            ? `${artwork.width.toLocaleString()} × ${artwork.height.toLocaleString()}px`
                            : "Dimensions unavailable"}
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Action buttons */}
                  <div className="p-4 flex items-center gap-2">
                    <button
                      onClick={(e) => handleDeleteClick(artwork, e)}
                      className="inline-flex items-center px-3 py-2 border border-red-300 text-sm leading-4 font-medium rounded-md text-red-700 bg-white hover:bg-red-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 transition-colors"
                      title="Delete image"
                    >
                      <SvgIcon name="DeleteIcon" className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Preview Modal */}
      {previewImage && (
        <ImagePreviewModal
          imageId={previewImage.id}
          onClose={handleClosePreview}
        />
      )}
    </div>
  );
}

export default UploadsManager;
