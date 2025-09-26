import React, { useState, useEffect } from "react";
import axios from "axios";

function FulfilmentToggle({
  productId,
  storeId,
  initialActive = false,
  activeVariants = 0,
  totalVariants = 0,
  onToggle,
}) {
  const [isActive, setIsActive] = useState(initialActive);
  const [isLoading, setIsLoading] = useState(false);

  // Update local state when parent state changes
  useEffect(() => {
    setIsActive(initialActive);
  }, [initialActive]);

  const handleToggle = async () => {
    const newState = !isActive;
    if (onToggle) {
      // Use parent's toggle handler with the specific new state
      setIsLoading(true);
      await onToggle(newState);
      setIsLoading(false);
    } else {
      // Fallback to original behavior
      setIsLoading(true);

      try {
        const response = await axios.patch(
          `/connections/stores/${storeId}/products/${productId}/toggle_fulfilment`,
          {},
          {
            headers: {
              "Content-Type": "application/json",
              "X-CSRF-Token": document
                .querySelector('meta[name="csrf-token"]')
                .getAttribute("content"),
            },
          }
        );

        if (response.data.success) {
          setIsActive(response.data.fulfilment_active);
          console.log(response.data.message);
        } else {
          console.error("Error toggling fulfilment:", response.data.error);
        }
      } catch (error) {
        console.error("Network error:", error.response?.data || error.message);
      } finally {
        setIsLoading(false);
      }
    }
  };

  return (
    <div className="flex items-center space-x-3">
      <div className="flex flex-col items-end">
        <div className="flex items-center space-x-3">
          <span className="text-gray-900 font-medium text-sm">
            Fulfil this item with Framefox
          </span>
          <button
            onClick={handleToggle}
            disabled={isLoading}
            className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 ${
              isActive ? "bg-blue-600" : "bg-gray-200"
            } ${
              isLoading ? "opacity-50 cursor-not-allowed" : "cursor-pointer"
            }`}
          >
            <span
              className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                isActive ? "translate-x-6" : "translate-x-1"
              }`}
            />
          </button>
        </div>
        {totalVariants > 0 && (
          <div className="text-xs text-gray-500 mt-1">
            ({activeVariants} of {totalVariants} variants active)
          </div>
        )}
      </div>
    </div>
  );
}

export default FulfilmentToggle;
