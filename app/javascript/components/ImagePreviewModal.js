import React, { useState, useEffect } from "react";
import axios from "axios";

function ImagePreviewModal({ imageId, onClose, onTitleUpdate }) {
  const [imageData, setImageData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [isEditingTitle, setIsEditingTitle] = useState(false);
  const [editedTitle, setEditedTitle] = useState("");
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    fetchImageDetails();
  }, [imageId]);

  const fetchImageDetails = async () => {
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

      const apiAuthToken = window.FramefoxConfig?.apiAuthToken;
      const response = await axios.get(
        `${window.FramefoxConfig.apiUrl}/shopify-customers/${window.FramefoxConfig.shopifyCustomerId}/images/${imageId}.json`,
        {
          params: apiAuthToken ? { auth: apiAuthToken } : {},
        }
      );
      setImageData(response.data);
    } catch (err) {
      setError("Failed to load image details. Please try again.");
      console.error("Error fetching image details:", err);
    } finally {
      setLoading(false);
    }
  };

  const handleEditTitle = () => {
    setEditedTitle(imageData.title || "");
    setIsEditingTitle(true);
  };

  const handleCancelEdit = () => {
    setIsEditingTitle(false);
    setEditedTitle("");
  };

  const handleSaveTitle = async () => {
    if (!editedTitle.trim()) {
      alert("Title cannot be empty");
      return;
    }

    setIsSaving(true);
    try {
      const apiAuthToken = window.FramefoxConfig?.apiAuthToken;
      const response = await axios.patch(
        `${window.FramefoxConfig.apiUrl}/shopify-customers/${window.FramefoxConfig.shopifyCustomerId}/images/${imageId}`,
        {
          image: {
            filename: editedTitle,
          },
        },
        {
          params: apiAuthToken ? { auth: apiAuthToken } : {},
          headers: {
            "Content-Type": "application/json",
          },
        }
      );

      // Update local state with the new title
      setImageData({ ...imageData, title: editedTitle });
      setIsEditingTitle(false);
      setEditedTitle("");

      // Notify parent component of the title update
      if (onTitleUpdate) {
        onTitleUpdate(imageId, editedTitle);
      }
    } catch (err) {
      alert("Failed to update title. Please try again.");
      console.error("Error updating image title:", err);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 overflow-y-auto"
      aria-labelledby="modal-title"
      role="dialog"
      aria-modal="true"
    >
      {/* Background overlay */}
      <div
        className="fixed inset-0 bg-black opacity-50 transition-opacity"
        onClick={onClose}
      ></div>

      {/* Modal panel */}
      <div className="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
        <div className="relative transform overflow-hidden rounded-lg bg-white text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-4xl">
          {/* Close button */}
          <button
            onClick={onClose}
            className="absolute top-4 right-4 z-10 inline-flex items-center justify-center rounded-md bg-white p-2 text-gray-400 hover:bg-gray-100 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
          >
            <span className="sr-only">Close</span>
            <svg
              className="h-6 w-6"
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

          {/* Modal content */}
          <div className="bg-white px-4 pb-4 pt-5 sm:p-6">
            {loading && (
              <div className="flex items-center justify-center py-12">
                <i className="fa-solid fa-spinner-third fa-spin text-blue-600 text-3xl"></i>
                <span className="ml-3 text-gray-600">
                  Loading image details...
                </span>
              </div>
            )}

            {error && (
              <div className="text-center py-12">
                <div className="text-red-600 mb-4">{error}</div>
                <button
                  onClick={fetchImageDetails}
                  className="px-4 py-2 bg-slate-900 text-slate-50 hover:bg-slate-800 rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
                >
                  Try Again
                </button>
              </div>
            )}

            {!loading && !error && imageData && (
              <div className="space-y-6">
                {/* Image Preview */}
                <div
                  className="bg-gray-50 rounded-lg p-4 flex items-center justify-center"
                  style={{ minHeight: "400px" }}
                >
                  <img
                    src={imageData.url}
                    alt={imageData.title}
                    className="max-w-full max-h-96 object-contain"
                  />
                </div>

                {/* Image Details */}
                <div className="border-t border-gray-200 pt-6">
                  <h3 className="text-lg font-medium text-gray-900 mb-4">
                    Image Details
                  </h3>
                  <dl className="grid grid-cols-1 gap-x-4 gap-y-4 sm:grid-cols-2">
                    <div className="sm:col-span-2">
                      <dt className="text-sm font-medium text-gray-500 mb-2">
                        Title
                      </dt>
                      <dd className="mt-1">
                        {!isEditingTitle ? (
                          <div className="flex items-center group">
                            <span className="text-sm text-gray-900">
                              {imageData.title || "N/A"}
                            </span>
                            <button
                              onClick={handleEditTitle}
                              className="ml-2 px-2 py-1 text-xs text-slate-600 hover:text-slate-900 hover:bg-gray-100 rounded transition-colors opacity-0 group-hover:opacity-100 focus:opacity-100 focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-1"
                            >
                              Edit
                            </button>
                          </div>
                        ) : (
                          <div className="space-y-2">
                            <input
                              type="text"
                              value={editedTitle}
                              onChange={(e) => setEditedTitle(e.target.value)}
                              className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm text-sm focus:outline-none focus:ring-2 focus:ring-slate-950 focus:border-transparent"
                              placeholder="Enter image title"
                              autoFocus
                              disabled={isSaving}
                            />
                            <div className="flex items-center space-x-2">
                              <button
                                onClick={handleSaveTitle}
                                disabled={isSaving}
                                className="inline-flex items-center px-3 py-2 bg-slate-900 text-white text-sm font-medium rounded-md hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
                              >
                                {isSaving ? (
                                  <>
                                    <i className="fa-solid fa-spinner-third fa-spin mr-2"></i>
                                    Saving...
                                  </>
                                ) : (
                                  "Save"
                                )}
                              </button>
                              <button
                                onClick={handleCancelEdit}
                                disabled={isSaving}
                                className="px-3 py-2 bg-white text-gray-700 text-sm font-medium rounded-md border border-gray-300 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
                              >
                                Cancel
                              </button>
                            </div>
                          </div>
                        )}
                      </dd>
                    </div>
                    <div>
                      <dt className="text-sm font-medium text-gray-500">
                        Image Key
                      </dt>
                      <dd className="mt-1 text-sm text-gray-900">
                        {imageData.key || "N/A"}
                      </dd>
                    </div>
                    <div>
                      <dt className="text-sm font-medium text-gray-500">
                        Dimensions
                      </dt>
                      <dd className="mt-1 text-sm text-gray-900">
                        {imageData.width && imageData.height
                          ? `${imageData.width.toLocaleString()} × ${imageData.height.toLocaleString()} pixels`
                          : "N/A"}
                      </dd>
                    </div>
                    <div className="sm:col-span-2">
                      <dt className="text-sm font-medium text-gray-500">
                        Uploaded
                      </dt>
                      <dd className="mt-1 text-sm text-gray-900">
                        {imageData.created_at || "N/A"}
                      </dd>
                    </div>
                  </dl>
                </div>
              </div>
            )}
          </div>

          {/* Modal footer */}
          <div className="bg-gray-50 px-4 py-3 sm:flex sm:flex-row-reverse sm:px-6">
            <button
              type="button"
              onClick={onClose}
              className="inline-flex w-full justify-center rounded-md bg-slate-900 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 sm:ml-3 sm:w-auto"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export default ImagePreviewModal;
