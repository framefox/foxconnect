import React, { useState, useEffect } from "react";
import axios from "axios";

function ImagePreviewModal({ imageId, onClose }) {
  const [imageData, setImageData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

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

      const response = await axios.get(
        `${window.FramefoxConfig.apiUrl}/shopify-customers/${window.FramefoxConfig.shopifyCustomerId}/images/${imageId}.json`
      );
      setImageData(response.data);
    } catch (err) {
      setError("Failed to load image details. Please try again.");
      console.error("Error fetching image details:", err);
    } finally {
      setLoading(false);
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
                      <dt className="text-sm font-medium text-gray-500">
                        Title
                      </dt>
                      <dd className="mt-1 text-sm text-gray-900">
                        {imageData.title || "N/A"}
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
