import React, { useState } from "react";

function FulfilmentToggle({
  productId,
  storeId,
  initialActive = false,
  activeVariants = 0,
  totalVariants = 0,
}) {
  const [isActive, setIsActive] = useState(initialActive);
  const [isLoading, setIsLoading] = useState(false);

  const handleToggle = async () => {
    setIsLoading(true);

    try {
      const response = await fetch(
        `/connections/stores/${storeId}/products/${productId}/toggle_fulfilment`,
        {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
          },
        }
      );

      const data = await response.json();

      if (data.success) {
        setIsActive(data.fulfilment_active);
        // Show success feedback (could be a toast notification)
        console.log(data.message);
      } else {
        console.error("Error toggling fulfilment:", data.error);
        // Revert the toggle on error
      }
    } catch (error) {
      console.error("Network error:", error);
      // Revert the toggle on error
    } finally {
      setIsLoading(false);
    }
  };

  return React.createElement(
    "div",
    {
      className: "flex items-center space-x-3",
    },
    [
      React.createElement(
        "div",
        {
          className: "flex flex-col items-end",
          key: "content",
        },
        [
          React.createElement(
            "div",
            {
              className: "flex items-center space-x-3",
              key: "main-content",
            },
            [
              React.createElement(
                "span",
                {
                  className: "text-gray-900 font-medium text-sm",
                  key: "label",
                },
                "Fulfil this item with Framefox"
              ),
              React.createElement(
                "button",
                {
                  onClick: handleToggle,
                  disabled: isLoading,
                  className: `relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 ${
                    isActive ? "bg-blue-600" : "bg-gray-200"
                  } ${
                    isLoading
                      ? "opacity-50 cursor-not-allowed"
                      : "cursor-pointer"
                  }`,
                  key: "toggle",
                },
                React.createElement("span", {
                  className: `inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                    isActive ? "translate-x-6" : "translate-x-1"
                  }`,
                })
              ),
            ]
          ),
          totalVariants > 0 &&
            React.createElement(
              "div",
              {
                className: "text-xs text-gray-500 mt-1",
                key: "variant-info",
              },
              `(${activeVariants} of ${totalVariants} variants active)`
            ),
        ]
      ),
    ]
  );
}

export default FulfilmentToggle;
