import React, { useState } from "react";
import ProductSelectModal from "./ProductSelectModal";
import axios from "axios";

function OrderItemCard({ item, currency, showRestoreButton = false }) {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [variantMapping, setVariantMapping] = useState(
    item.variant_mapping || null
  );
  const [imageLoading, setImageLoading] = useState(true);
  const [isDeleting, setIsDeleting] = useState(false);
  const [isRestoring, setIsRestoring] = useState(false);
  const [isHovered, setIsHovered] = useState(false);
  const [showDropdown, setShowDropdown] = useState(false);
  const [replaceImageMode, setReplaceImageMode] = useState(false);

  const hasVariantMapping = variantMapping !== null;

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: currency || "USD",
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(amount);
  };

  const handleDeleteItem = async () => {
    if (
      !confirm(
        "Remove this item from the order? You can restore it until order is in production."
      )
    ) {
      return;
    }

    setIsDeleting(true);
    try {
      const response = await axios.delete(
        `/orders/${item.order_id}/order_items/${item.id}/soft_delete`,
        {
          headers: {
            "X-Requested-With": "XMLHttpRequest",
            "X-CSRF-Token": document
              .querySelector('meta[name="csrf-token"]')
              .getAttribute("content"),
          },
        }
      );

      if (response.status >= 200 && response.status < 300) {
        console.log("Order item deleted successfully");
        // Refresh the page to reflect the updated order items
        window.location.reload();
      }
    } catch (error) {
      console.error("Error deleting order item:", error);
      alert("Failed to delete order item. Please try again.");
    } finally {
      setIsDeleting(false);
    }
  };

  const handleRestoreItem = async () => {
    setIsRestoring(true);
    try {
      const response = await axios.patch(
        `/orders/${item.order_id}/order_items/${item.id}/restore`,
        {},
        {
          headers: {
            "X-Requested-With": "XMLHttpRequest",
            "X-CSRF-Token": document
              .querySelector('meta[name="csrf-token"]')
              .getAttribute("content"),
          },
        }
      );

      if (response.status >= 200 && response.status < 300) {
        console.log("Order item restored successfully");
        // Refresh the page to reflect the updated order items
        window.location.reload();
      }
    } catch (error) {
      console.error("Error restoring order item:", error);
      alert("Failed to restore order item. Please try again.");
    } finally {
      setIsRestoring(false);
    }
  };

  return (
    <div
      className="p-6"
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      <div className="flex items-start space-x-4">
        {/* Product Image */}
        <div className="w-24 h-24 bg-slate-100 rounded-lg flex items-center justify-center flex-shrink-0">
          {hasVariantMapping && variantMapping.framed_preview_thumbnail ? (
            <div className="h-24 w-24 relative flex items-center justify-center">
              {imageLoading && (
                <div className="absolute inset-0 flex items-center justify-center bg-slate-100 rounded-lg">
                  <i className="fa-solid fa-spinner-third fa-spin text-slate-400"></i>
                </div>
              )}
              <img
                src={variantMapping.framed_preview_thumbnail}
                alt={item.display_name}
                className={`${
                  variantMapping.ch > variantMapping.cw ? "h-full" : "w-full"
                } object-contain ${
                  imageLoading ? "opacity-0" : "opacity-100"
                } transition-opacity duration-200`}
                onLoad={() => setImageLoading(false)}
                onError={() => setImageLoading(false)}
              />
            </div>
          ) : (
            <i className="fa-solid fa-image text-slate-400"></i>
          )}
        </div>

        {/* Product Details */}
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between">
            <div className="flex-1">
              <h4 className="font-medium text-slate-900">
                {item.display_name}
              </h4>
              {item.sku && (
                <p className="text-sm text-slate-500 mt-1">SKU: {item.sku}</p>
              )}
              <div className="flex items-center space-x-4 mt-2">
                <span className="text-sm text-slate-600">
                  Qty: {item.quantity}
                </span>
              </div>
            </div>
            <div className="text-right">
              <div className="flex items-center space-x-2">
                {showRestoreButton ? (
                  <button
                    onClick={handleRestoreItem}
                    disabled={isRestoring}
                    className={`inline-flex items-center px-2 py-1 border border-transparent text-xs leading-4 font-medium rounded-md text-slate-600 bg-slate-100 hover:bg-slate-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed ${
                      isHovered ? "opacity-100" : "opacity-0"
                    }`}
                  >
                    Restore
                  </button>
                ) : (
                  <>
                    <button
                      onClick={handleDeleteItem}
                      disabled={isDeleting}
                      className={`inline-flex items-center px-2 py-1 border border-transparent text-xs leading-4 font-medium rounded text-slate-600 hover:text-red-700 hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed ${
                        isHovered ? "opacity-100" : "opacity-0"
                      }`}
                      title="Remove order item"
                    >
                      {isDeleting ? "Removing..." : "Remove"}
                    </button>
                  </>
                )}
              </div>
            </div>
          </div>
          {!showRestoreButton && (
            <>
              {hasVariantMapping ? (
                <div className="flex items-center justify-between mt-2 p-3 border border-slate-200 rounded-sm">
                  <div className="text-sm font-medium text-slate-900">
                    Fulfilled as{" "}
                    <div className="text-xs text-slate-500">
                      {variantMapping.frame_sku_title}
                    </div>
                    <div className="text-xs text-slate-500">
                      Image: {variantMapping.image_filename}
                    </div>
                  </div>
                  <div className="flex items-center space-x-2">
                    <span className="inline-flex items-center rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800">
                      <i className="fa-solid fa-check w-3 h-3 mr-1"></i>
                      Ready
                    </span>
                    <div className="relative">
                      <button
                        onClick={() => setShowDropdown(!showDropdown)}
                        className="inline-flex items-center px-2 py-1 text-xs leading-4 font-medium rounded text-slate-700 bg-white hover:bg-slate-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 transition-colors"
                        title="More options"
                      >
                        <i className="fa-solid fa-ellipsis w-3 h-3"></i>
                      </button>

                      {showDropdown && (
                        <>
                          {/* Backdrop to close dropdown */}
                          <div
                            className="fixed inset-0 z-10"
                            onClick={() => setShowDropdown(false)}
                          />
                          {/* Dropdown menu */}
                          <div className="absolute right-0 top-full mt-1 w-56 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 z-20">
                            <div className="py-1" role="menu">
                              <button
                                onClick={() => {
                                  setShowDropdown(false);
                                  setIsModalOpen(true);
                                }}
                                className="flex items-center w-full px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 hover:text-slate-900 transition-colors"
                                role="menuitem"
                              >
                                <i className="fa-solid fa-repeat w-4 h-4 mr-3"></i>
                                Replace product & image
                              </button>
                              <button
                                onClick={() => {
                                  setShowDropdown(false);
                                  setReplaceImageMode(true);
                                  setIsModalOpen(true);
                                }}
                                className="flex items-center w-full px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 hover:text-slate-900 transition-colors"
                                role="menuitem"
                              >
                                <i className="fa-solid fa-image w-4 h-4 mr-3"></i>
                                Replace image only
                              </button>
                            </div>
                          </div>
                        </>
                      )}
                    </div>
                  </div>
                </div>
              ) : (
                <div className="flex items-center justify-between mt-2 p-3 bg-yellow-50 rounded-sm">
                  <div className="flex items-center space-x-2">
                    <button
                      onClick={() => setIsModalOpen(true)}
                      className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-slate-800 bg-white hover:bg-slate-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-950 transition-colors"
                    >
                      <i className="fa-solid fa-search w-3 h-3 mr-2 "></i>
                      Choose product & image
                    </button>
                  </div>
                  <div className="text-sm font-medium text-slate-900">
                    No product or image selected
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </div>

      {/* Product Select Modal */}
      {item.product_variant_id && (
        <ProductSelectModal
          isOpen={isModalOpen}
          onRequestClose={() => {
            setIsModalOpen(false);
            setReplaceImageMode(false);
          }}
          productVariantId={item.product_variant_id}
          orderItemId={item.id}
          replaceImageMode={replaceImageMode}
          existingVariantMapping={replaceImageMode ? variantMapping : null}
          onProductSelect={(selection) => {
            if (selection.variantMapping) {
              setVariantMapping(selection.variantMapping);
              setImageLoading(true);
              console.log("Variant mapping created:", selection.variantMapping);
            }
          }}
        />
      )}
    </div>
  );
}

export default OrderItemCard;
