import React, { useState, useEffect } from "react";
import axios from "axios";

function VariantCard({ variant, storeId, onToggle }) {
  const [isActive, setIsActive] = useState(variant.fulfilment_active);
  const [isLoading, setIsLoading] = useState(false);

  // Update local state when parent state changes
  useEffect(() => {
    setIsActive(variant.fulfilment_active);
  }, [variant.fulfilment_active]);

  const handleToggle = async () => {
    setIsLoading(true);

    try {
      const response = await axios.patch(
        `/connections/stores/${storeId}/product_variants/${variant.id}/toggle_fulfilment`,
        {},
        {
          headers: {
            "Content-Type": "application/json",
            "X-Requested-With": "XMLHttpRequest",
            "X-CSRF-Token": document
              .querySelector('meta[name="csrf-token"]')
              .getAttribute("content"),
          },
        }
      );

      if (response.data.success) {
        const newState = response.data.fulfilment_active;
        setIsActive(newState);
        // Notify parent of state change
        if (onToggle) {
          onToggle(variant.id, newState);
        }
        console.log(response.data.message);
      } else {
        console.error(
          "Error toggling variant fulfilment:",
          response.data.error
        );
      }
    } catch (error) {
      console.error("Network error:", error.response?.data || error.message);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="bg-white border border-slate-200 rounded-lg overflow-hidden transition-shadow">
      <div className="p-6">
        <div className="flex items-center justify-between">
          {/* Variant Info */}
          <div className="flex items-center space-x-4 flex-1">
            {/* Details */}
            <div className="flex-1 min-w-0">
              <h3 className="text-lg font-medium text-slate-900 truncate">
                {variant.title}{" "}
                <span className="text-sm text-slate-500 mt-1">
                  / {variant.external_variant_id}
                </span>
              </h3>
            </div>
          </div>

          {/* Fulfilment Control */}
          <div className="flex-shrink-0 ml-6">
            <div className="flex items-center space-x-3">
              {/* Status Badge */}
              <span
                className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium whitespace-nowrap ${
                  isActive
                    ? "bg-green-100 text-green-800"
                    : "bg-gray-100 text-gray-800"
                }`}
              >
                {isActive && (
                  <svg
                    className="w-3 h-3 mr-1"
                    fill="currentColor"
                    viewBox="0 0 20 20"
                  >
                    <path
                      fillRule="evenodd"
                      d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                      clipRule="evenodd"
                    />
                  </svg>
                )}
                {isActive ? "Fulfilment enabled" : "Fulfilment disabled"}
              </span>

              {/* Toggle Switch */}
              <button
                onClick={handleToggle}
                disabled={isLoading}
                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 ${
                  isActive ? "bg-blue-600" : "bg-gray-200"
                } ${
                  isLoading ? "opacity-50 cursor-not-allowed" : "cursor-pointer"
                }`}
                title={isActive ? "Fulfilment active" : "Fulfilment inactive"}
              >
                <span
                  className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                    isActive ? "translate-x-6" : "translate-x-1"
                  }`}
                />
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Slide-down Panel */}
      {isActive && (
        <div className="bg-yellow-50 border-t border-blue-100 p-6">
          <div className="">
            <p className="text-slate-700 text-sm mb-4">
              Add a product and an image to have Framefox fulfil this item
              automatically.
            </p>

            <button className="inline-flex items-center px-4 py-2 border border-blue-300 rounded-md text-sm font-medium text-blue-700 bg-white hover:bg-blue-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-colors">
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
                  d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                />
              </svg>
              Choose product
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export default VariantCard;
