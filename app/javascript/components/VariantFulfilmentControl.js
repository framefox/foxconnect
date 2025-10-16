import React, { useState } from "react";
import axios from "axios";

function VariantFulfilmentControl({
  variantId,
  storeId,
  initialActive = false,
}) {
  const [isActive, setIsActive] = useState(initialActive);
  const [isLoading, setIsLoading] = useState(false);

  const handleToggle = async () => {
    setIsLoading(true);

    try {
      const response = await axios.patch(
        `/connections/stores/${storeId}/product_variants/${variantId}/toggle_fulfilment`,
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
        setIsActive(response.data.fulfilment_active);
        // Show success feedback (could be a toast notification)
        console.log(response.data.message);
      } else {
        console.error(
          "Error toggling variant fulfilment:",
          response.data.error
        );
        // Revert the toggle on error
      }
    } catch (error) {
      console.error("Network error:", error.response?.data || error.message);
      // Revert the toggle on error
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="flex items-center space-x-3">
      {/* Status Badge */}
      <span
        className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium whitespace-nowrap ${
          isActive ? "bg-green-100 text-green-800" : "bg-gray-100 text-gray-800"
        }`}
      >
        {isActive && (
          <svg className="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
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
        className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 ${
          isActive ? "bg-blue-800" : "bg-gray-200"
        } ${isLoading ? "opacity-50 cursor-not-allowed" : "cursor-pointer"}`}
        title={isActive ? "Fulfilment active" : "Fulfilment inactive"}
      >
        <span
          className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
            isActive ? "translate-x-6" : "translate-x-1"
          }`}
        />
      </button>
    </div>
  );
}

export default VariantFulfilmentControl;
