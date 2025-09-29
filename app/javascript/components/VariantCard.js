import React, { useState, useEffect } from "react";
import axios from "axios";
import ProductSelectModal from "./ProductSelectModal";

function VariantCard({ variant, storeId, onToggle }) {
  const [isActive, setIsActive] = useState(variant.fulfilment_active);
  const [isLoading, setIsLoading] = useState(false);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [imageLoading, setImageLoading] = useState(true);
  const [variantMapping, setVariantMapping] = useState(
    variant.variant_mapping || null
  );
  const [isSyncing, setIsSyncing] = useState(false);

  // Update local state when parent state changes
  useEffect(() => {
    setIsActive(variant.fulfilment_active);
    setVariantMapping(variant.variant_mapping || null);
    if (variant.variant_mapping) {
      setImageLoading(true);
    }
  }, [variant.fulfilment_active, variant.variant_mapping]);

  // Reset image loading when variant mapping changes
  useEffect(() => {
    if (variantMapping && variantMapping.framed_preview_thumbnail) {
      setImageLoading(true);
    }
  }, [variantMapping?.framed_preview_thumbnail]);

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

  const handleRemoveMapping = async () => {
    if (!variantMapping || !variantMapping.id) {
      setVariantMapping(null);
      return;
    }

    try {
      await axios.delete(`/variant_mappings/${variantMapping.id}`, {
        headers: {
          "Content-Type": "application/json",
          "X-Requested-With": "XMLHttpRequest",
          "X-CSRF-Token": document
            .querySelector('meta[name="csrf-token"]')
            .getAttribute("content"),
        },
      });

      setVariantMapping(null);
      console.log("Variant mapping removed");
    } catch (error) {
      console.error("Error removing variant mapping:", error);
      // You might want to show an error message to the user here
    }
  };

  const handleSyncToShopify = async () => {
    if (!variantMapping || !variantMapping.id) {
      console.error("No variant mapping to sync");
      return;
    }

    setIsSyncing(true);

    try {
      const response = await axios.patch(
        `/variant_mappings/${variantMapping.id}/sync_to_shopify`,
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
        console.log("Successfully synced to Shopify:", response.data.message);
        // You could show a success message here
      } else {
        console.error("Error syncing to Shopify:", response.data.error);
        // You could show an error message here
      }
    } catch (error) {
      console.error(
        "Network error syncing to Shopify:",
        error.response?.data || error.message
      );
      // You could show an error message here
    } finally {
      setIsSyncing(false);
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
                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 ${
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
        <div
          className={`${
            variantMapping
              ? "bg-slate-50 border-t border-slate-200"
              : "bg-yellow-50 border-t border-yellow-100"
          } p-6`}
        >
          <div className="">
            {!variantMapping && (
              <p className="text-slate-700 text-sm mb-4">
                Add a product and an image to have Framefox fulfil this item
                automatically.
              </p>
            )}

            <div className="space-y-3">
              {variantMapping && (
                <div className="bg-white rounded-md p-3">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-3">
                      {variantMapping.framed_preview_thumbnail && (
                        <div className="w-24 h-24 flex-shrink-0 flex items-center justify-center relative">
                          {imageLoading && (
                            <div className="absolute inset-0 flex items-center justify-center bg-gray-50 rounded">
                              <i className="fa-solid fa-spinner-third fa-spin text-gray-400"></i>
                            </div>
                          )}
                          <img
                            src={variantMapping.framed_preview_thumbnail}
                            alt="Framed artwork preview"
                            className={`${
                              variantMapping.ch > variantMapping.cw
                                ? "h-full"
                                : "w-full"
                            } object-contain ${
                              imageLoading ? "opacity-0" : "opacity-100"
                            } transition-opacity duration-200`}
                            onLoad={() => setImageLoading(false)}
                            onError={() => setImageLoading(false)}
                          />
                        </div>
                      )}
                      <div className="flex-1">
                        <div className="flex items-center space-x-2">
                          <p className="text-sm font-medium text-gray-900">
                            {variantMapping.frame_sku_code}
                          </p>
                          <span className="text-gray-400">+</span>
                          <span className="text-xs text-gray-600">
                            Image #{variantMapping.image_id}
                          </span>
                        </div>
                        <p className="text-xs text-gray-500 truncate max-w-xs">
                          {variantMapping.frame_sku_title}
                        </p>
                        <div className="text-xs text-gray-400 mt-1">
                          Crop: {variantMapping.cx},{variantMapping.cy} -{" "}
                          {variantMapping.cw}×{variantMapping.ch}px
                        </div>
                      </div>
                    </div>
                    <div className="flex items-center space-x-2">
                      <button
                        onClick={handleSyncToShopify}
                        disabled={isSyncing}
                        className={`inline-flex items-center px-2 py-1 text-xs font-medium rounded transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-1 ${
                          isSyncing
                            ? "bg-blue-100 text-blue-600 cursor-not-allowed"
                            : "bg-blue-50 text-blue-700 hover:bg-blue-100"
                        }`}
                        title="Sync image to Shopify variant"
                      >
                        {isSyncing ? (
                          <>
                            <i className="fa-solid fa-spinner-third fa-spin mr-1"></i>
                            Syncing...
                          </>
                        ) : (
                          <>
                            <svg
                              className="w-3 h-3 mr-1"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth="2"
                                d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                              />
                            </svg>
                            Sync image
                          </>
                        )}
                      </button>
                      <button
                        onClick={handleRemoveMapping}
                        className="text-gray-400 hover:text-gray-600"
                        title="Remove mapping"
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

              {!variantMapping && (
                <button
                  onClick={() => setIsModalOpen(true)}
                  className="inline-flex items-center px-4 py-2 bg-white text-slate-900 hover:bg-slate-200 rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
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
                  Choose product & image
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      <ProductSelectModal
        isOpen={isModalOpen}
        onRequestClose={() => setIsModalOpen(false)}
        productVariantId={variant.id}
        onProductSelect={(selection) => {
          // The selection now contains the full variantMapping from the backend
          if (selection.variantMapping) {
            setVariantMapping(selection.variantMapping);
            console.log("Variant mapping created:", selection.variantMapping);
          }
        }}
      />
    </div>
  );
}

export default VariantCard;
