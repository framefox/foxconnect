import React, { useState, useEffect } from "react";
import axios from "axios";
import ProductSelectModal from "./ProductSelectModal";

function VariantCard({ variant, storeId, onToggle }) {
  const [isActive, setIsActive] = useState(variant.fulfilment_active);
  const [isLoading, setIsLoading] = useState(false);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedProduct, setSelectedProduct] = useState(null);

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
        <div className="bg-blue-50 border-t border-blue-100 p-6">
          <div className="">
            <p className="text-slate-700 text-sm mb-4">
              Add a product and an image to have Framefox fulfil this item
              automatically.
            </p>

            <div className="space-y-3">
              {selectedProduct && (
                <div className="bg-white border border-green-200 rounded-md p-3">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-3">
                      {selectedProduct.product &&
                        selectedProduct.product.preview_image && (
                          <img
                            src={selectedProduct.product.preview_image}
                            alt={selectedProduct.product.description}
                            className="h-10 w-10 object-cover rounded-md"
                          />
                        )}
                      <div className="flex-1">
                        <div className="flex items-center space-x-2">
                          <p className="text-sm font-medium text-gray-900">
                            {selectedProduct.product
                              ? selectedProduct.product.code
                              : selectedProduct.code}
                          </p>
                          {selectedProduct.artwork && (
                            <>
                              <span className="text-gray-400">+</span>
                              <img
                                src={
                                  selectedProduct.artwork.thumb ||
                                  selectedProduct.artwork.url
                                }
                                alt={selectedProduct.artwork.filename}
                                className="h-6 w-6 object-cover rounded border"
                              />
                              <span className="text-xs text-gray-600">
                                {selectedProduct.artwork.filename}
                              </span>
                            </>
                          )}
                        </div>
                        <p className="text-xs text-gray-500 truncate max-w-xs">
                          {selectedProduct.product
                            ? selectedProduct.product.description
                            : selectedProduct.description}
                        </p>
                      </div>
                    </div>
                    <div className="flex items-center space-x-2">
                      <span className="text-sm font-medium text-gray-900">
                        $
                        {selectedProduct.product
                          ? selectedProduct.product.price
                          : selectedProduct.price}
                      </span>
                      <button
                        onClick={() => setSelectedProduct(null)}
                        className="text-gray-400 hover:text-gray-600"
                      >
                        <svg
                          className="w-4 h-4"
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
                  </div>
                </div>
              )}

              <button
                onClick={() => setIsModalOpen(true)}
                className="inline-flex items-center px-4 py-2 border border-blue-300 rounded-md text-sm font-medium text-blue-700 bg-white hover:bg-blue-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-colors"
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
                    d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                  />
                </svg>
                {selectedProduct ? "Change product" : "Choose product"}
              </button>
            </div>
          </div>
        </div>
      )}

      <ProductSelectModal
        isOpen={isModalOpen}
        onRequestClose={() => setIsModalOpen(false)}
        onProductSelect={(selection) => {
          setSelectedProduct(selection);
          console.log("Selected product and artwork:", selection);
        }}
      />
    </div>
  );
}

export default VariantCard;
