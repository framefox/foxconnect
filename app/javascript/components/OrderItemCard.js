import React, { useState, useRef, useEffect } from "react";
import ProductSelectModal from "./ProductSelectModal";
import { Lightbox, SvgIcon } from "../components";
import axios from "axios";

function OrderItemCard({
  item,
  currency,
  apiUrl,
  countryCode,
  showRestoreButton = false,
  readOnly = false,
  productTypeImages = {},
}) {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentSlotPosition, setCurrentSlotPosition] = useState(null);
  
  // Bundle support - check if order item has multiple variant mappings
  const bundleMappings = item.variant_mappings || [];
  const isBundle = bundleMappings.length > 1;
  const slotCount = item.bundle_slot_count || 1;
  
  const [variantMapping, setVariantMapping] = useState(
    item.variant_mapping || null
  );
  const [imageLoading, setImageLoading] = useState(true);
  const [isDeleting, setIsDeleting] = useState(false);
  const [isRestoring, setIsRestoring] = useState(false);
  const [isHovered, setIsHovered] = useState(false);
  const [showDropdown, setShowDropdown] = useState(false);
  const [replaceImageMode, setReplaceImageMode] = useState(false);
  const [isLightboxOpen, setIsLightboxOpen] = useState(false);
  const [bundleSlotLightboxOpen, setBundleSlotLightboxOpen] = useState(null); // Tracks which bundle slot's lightbox is open
  const imageRef = useRef(null);
  const loadingTimeoutRef = useRef(null);

  const hasVariantMapping = variantMapping !== null || bundleMappings.length > 0;

  // Helper functions for bundle support
  const getMappingForSlot = (slotPosition) => {
    return bundleMappings.find(m => m.slot_position === slotPosition) || null;
  };

  const calculateTotalFrameCost = () => {
    if (isBundle) {
      return bundleMappings.reduce((total, mapping) => {
        return total + (mapping?.frame_sku_cost_dollars || 0);
      }, 0) * item.quantity;
    }
    return (variantMapping?.frame_sku_cost_dollars || 0) * item.quantity;
  };

  const handleSlotClick = (slotPosition) => {
    setCurrentSlotPosition(slotPosition);
    const mapping = getMappingForSlot(slotPosition);
    setReplaceImageMode(!!mapping);
    setIsModalOpen(true);
  };

  // Calculate DPI based on crop dimensions and print size
  const calculateDPI = (mapping) => {
    if (
      !mapping ||
      !mapping.cw ||
      !mapping.ch ||
      !mapping.width ||
      !mapping.height ||
      !mapping.unit
    ) {
      return null;
    }

    // Crop dimensions are already in pixels
    const cropWidthPx = mapping.cw;
    const cropHeightPx = mapping.ch;

    // Get print size in inches
    const printWidth = parseFloat(mapping.width) || 0;
    const printHeight = parseFloat(mapping.height) || 0;
    const unit = mapping.unit || "in";

    let printWidthInches, printHeightInches;
    if (unit === "cm") {
      printWidthInches = printWidth / 2.54;
      printHeightInches = printHeight / 2.54;
    } else if (unit === "mm") {
      printWidthInches = printWidth / 25.4;
      printHeightInches = printHeight / 25.4;
    } else {
      // Assume inches
      printWidthInches = printWidth;
      printHeightInches = printHeight;
    }

    // Calculate DPI for width and height, return the minimum (limiting factor)
    const dpiWidth =
      printWidthInches > 0 ? Math.round(cropWidthPx / printWidthInches) : 0;
    const dpiHeight =
      printHeightInches > 0 ? Math.round(cropHeightPx / printHeightInches) : 0;

    return Math.min(dpiWidth, dpiHeight);
  };

  // Timeout fallback to prevent stuck loading state (only for single mappings)
  useEffect(() => {
    if (!isBundle && variantMapping && variantMapping.framed_preview_thumbnail) {
      setImageLoading(true);

      // Check if image is already loaded (cached)
      if (imageRef.current && imageRef.current.complete) {
        setImageLoading(false);
      }

      // Fallback timeout
      loadingTimeoutRef.current = setTimeout(() => {
        setImageLoading(false);
      }, 3000);
    }

    return () => {
      if (loadingTimeoutRef.current) {
        clearTimeout(loadingTimeoutRef.current);
      }
    };
  }, [isBundle, variantMapping?.framed_preview_thumbnail]);

  const handleImageLoad = () => {
    if (loadingTimeoutRef.current) {
      clearTimeout(loadingTimeoutRef.current);
    }
    setImageLoading(false);
  };

  const handleImageError = () => {
    if (loadingTimeoutRef.current) {
      clearTimeout(loadingTimeoutRef.current);
    }
    setImageLoading(false);
  };

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
        {/* Product Image/Images */}
        {isBundle ? (
          /* Bundle: Show compact grid of slot previews */
          <div className="flex-shrink-0 w-40">
            <div className="grid grid-cols-2 gap-1">
              {Array.from({ length: Math.min(slotCount, 4) }, (_, i) => i + 1).map(slotPosition => {
                const mapping = getMappingForSlot(slotPosition);
                return (
                  <div
                    key={slotPosition}
                    className={`aspect-square bg-slate-100 rounded flex items-center justify-center relative overflow-hidden ${
                      mapping?.framed_preview_thumbnail ? 'cursor-pointer group' : ''
                    }`}
                    onClick={() => mapping?.framed_preview_thumbnail && setBundleSlotLightboxOpen(slotPosition)}
                    title={mapping?.framed_preview_thumbnail ? "Click to view larger image" : ""}
                  >
                    {mapping?.framed_preview_thumbnail ? (
                      <>
                        <img
                          src={mapping.framed_preview_thumbnail}
                          alt={`Slot ${slotPosition}`}
                          className="w-full h-full object-contain"
                        />
                        {/* Zoom overlay indicator */}
                        <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-all duration-200 rounded flex items-center justify-center">
                          <SvgIcon
                            name="ViewIcon"
                            className="w-4 h-4 text-white opacity-0 group-hover:opacity-100 transition-opacity duration-200"
                          />
                        </div>
                      </>
                    ) : (
                      <span className="text-xs text-slate-400">{slotPosition}</span>
                    )}
                  </div>
                );
              })}
            </div>
            {slotCount > 4 && (
              <div className="text-xs text-slate-500 text-center mt-1">
                +{slotCount - 4} more
              </div>
            )}
          </div>
        ) : (
          /* Single mapping view */
          !isBundle && variantMapping && variantMapping.framed_preview_thumbnail ? (
          <div className="flex-shrink-0 flex flex-col items-center">
            <div
              className="h-36 w-36 bg-slate-100 rounded-lg relative flex items-center justify-center cursor-pointer group"
              onClick={() => setIsLightboxOpen(true)}
              title="Click to view larger image"
            >
              {imageLoading && (
                <div className="absolute inset-0 flex items-center justify-center bg-slate-100 rounded-lg">
                  <i className="fa-solid fa-spinner-third fa-spin text-slate-400"></i>
                </div>
              )}
              <img
                ref={imageRef}
                src={variantMapping.framed_preview_thumbnail}
                alt={item.display_name}
                className={`${
                  variantMapping.ch > variantMapping.cw ? "h-full" : "w-full"
                } object-contain ${
                  imageLoading ? "opacity-0" : "opacity-100"
                } transition-opacity duration-200`}
                onLoad={handleImageLoad}
                onError={handleImageError}
              />
              {/* Zoom overlay indicator */}
              <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-all duration-200 rounded-lg flex items-center justify-center">
                <SvgIcon
                  name="ViewIcon"
                  className="w-5 h-5 text-white opacity-0 group-hover:opacity-100 transition-opacity duration-200"
                />
              </div>
            </div>
            {(() => {
              const dpi = calculateDPI(variantMapping);
              if (dpi !== null) {
                if (dpi < 125) {
                  return (
                    <div className="mt-2 inline-flex items-center rounded-lg px-2 py-1 text-xs font-medium whitespace-nowrap bg-amber-50 text-amber-500">
                      Low: {dpi} DPI
                    </div>
                  );
                } else if (dpi >= 125 && dpi < 200) {
                  return (
                    <div className="mt-2 inline-flex items-center rounded-lg px-2 py-1 text-xs font-medium whitespace-nowrap bg-gray-100 text-gray-800">
                      OK: {dpi} DPI
                    </div>
                  );
                } else {
                  return (
                    <div className="mt-2 inline-flex items-center rounded-lg px-2 py-1 text-xs font-medium whitespace-nowrap bg-gray-100 text-gray-800">
                      High: {dpi} DPI
                    </div>
                  );
                }
              }
              return null;
            })()}
          </div>
        ) : !isBundle && variantMapping &&
          !variantMapping.framed_preview_thumbnail &&
          !readOnly ? (
          <button
            onClick={() => {
              setReplaceImageMode(true);
              setIsModalOpen(true);
            }}
            className="w-36 h-36 flex-shrink-0 flex flex-col items-center justify-center bg-amber-50 rounded-lg hover:bg-amber-100 transition-all cursor-pointer group"
            title="Click to add image"
          >
            <SvgIcon
              name="PlusCircleIcon"
              className="w-5 h-5 text-amber-600 group-hover:text-amber-700 mb-1 transition-colors"
            />
            <p className="text-xs text-amber-600 font-medium group-hover:text-amber-700 transition-colors">
              Add image
            </p>
          </button>
        ) : (
          <div className="w-36 h-36 bg-slate-100 rounded-lg flex items-center justify-center flex-shrink-0">
            <i className="fa-solid fa-image text-slate-400"></i>
          </div>
        )
        )}

        {/* Product Details */}
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between">
            <div className="flex-1">
              <h4 className="font-medium text-slate-900">
                {item.store_uid && item.product_id ? (
                  <a
                    href={`/connections/stores/${item.store_uid}/products/${item.product_id}`}
                    className="text-slate-900 hover:text-blue-600 transition-colors"
                  >
                    {item.display_name}
                  </a>
                ) : (
                  item.display_name
                )}
                {item.is_custom && (
                  <span className="inline-flex items-center rounded-lg bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-700 ml-2">
                    Custom Item
                  </span>
                )}
              </h4>
              {item.sku && (
                <p className="text-sm text-slate-500 mt-1">SKU: {item.sku}</p>
              )}
            </div>

            {/* Frame Cost, Quantity, and Action Buttons - Right Side */}
            <div className="text-right ml-4">
              <div className="flex items-center space-x-2 text-sm text-slate-900">
                {isBundle ? (
                  <>
                    <span className="text-xs text-slate-500">
                      {bundleMappings.length} items
                    </span>
                    <span>×</span>
                    <span className="inline-flex items-center rounded-lg bg-slate-100 px-2 py-0.5 text-sm font-medium text-slate-700">
                      {item.quantity}
                    </span>
                    {bundleMappings.length > 0 && (
                      <span className="text-sm font-medium text-slate-900 ml-4">
                        {formatCurrency(calculateTotalFrameCost())}
                      </span>
                    )}
                  </>
                ) : (
                  <>
                    <span>
                      {formatCurrency(variantMapping?.frame_sku_cost_dollars || 0)}
                    </span>
                    <span>×</span>
                    <span className="inline-flex items-center rounded-lg bg-slate-100 px-2 py-0.5 text-sm font-medium text-slate-700">
                      {item.quantity}
                    </span>
                    {variantMapping?.frame_sku_cost_dollars > 0 && (
                      <span className="text-sm font-medium text-slate-900 ml-4">
                        {formatCurrency(
                          variantMapping.frame_sku_cost_dollars * item.quantity
                        )}
                      </span>
                    )}
                  </>
                )}

                {/* Action Buttons */}
                {showRestoreButton ? (
                  <button
                    onClick={handleRestoreItem}
                    disabled={isRestoring}
                    className={`inline-flex items-center px-3 py-1.5 border border-transparent text-sm leading-4 font-medium rounded-md text-slate-600 bg-slate-100 hover:bg-slate-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed  ${
                      isHovered ? "opacity-100" : "opacity-0"
                    }`}
                  >
                    Restore
                  </button>
                ) : (
                  <>
                    {!readOnly && (
                      <button
                        onClick={handleDeleteItem}
                        disabled={isDeleting}
                        className={`inline-flex items-center px-2 py-1.5 border border-transparent text-sm leading-4 font-medium rounded text-slate-600 hover:text-red-700 hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed  ${
                          isHovered ? "opacity-100" : "opacity-0"
                        }`}
                        title="Remove order item"
                      >
                        <i className="fa-solid fa-trash text-xs"></i>
                      </button>
                    )}
                  </>
                )}
              </div>
            </div>
          </div>

          {!showRestoreButton && (
            <>
              {isBundle ? (
                /* Bundle slots detail */
                <div className="mt-2 p-3 border border-slate-200 rounded-sm space-y-2">
                  <div className="text-sm font-semibold text-slate-900 mb-2">
                    Bundle: {slotCount} items
                  </div>
                  {Array.from({ length: slotCount }, (_, i) => i + 1).map(slotPosition => {
                    const mapping = getMappingForSlot(slotPosition);
                    return (
                      <div key={slotPosition} className="flex items-center justify-between py-2 border-t border-slate-100 first:border-t-0">
                        <div className="flex-1">
                          {mapping ? (
                            <div className="text-sm text-slate-900">
                              <span className="font-medium">Slot {slotPosition}:</span> {mapping.frame_sku_title}
                              {mapping.image_filename && (
                                <span className="text-xs text-slate-500 ml-2">
                                  ({mapping.image_filename})
                                </span>
                              )}
                            </div>
                          ) : (
                            <div className="text-sm text-amber-600">
                              <span className="font-medium">Slot {slotPosition}:</span> Not configured
                            </div>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              ) : (
                !isBundle && variantMapping ? (
                <div className="flex items-center justify-between mt-2 p-3 border border-slate-200 rounded-sm">
                  <div className="text-sm font-medium text-slate-900">
                    Fulfilled as {variantMapping.dimensions_display}{" "}
                    <div className="mt-3">
                      {variantMapping.frame_sku_description
                        .split("|")
                        .map((part, index) => (
                          <div
                            className="inline-flex items-center rounded-lg px-2 py-1 text-xs font-medium whitespace-nowrap bg-gray-100 text-gray-500 mr-2 mb-2"
                            key={index}
                          >
                            {part.trim()}
                          </div>
                        ))}
                      {variantMapping.image_filename && (
                        <div className="inline-flex items-center rounded-lg px-2 py-1 text-xs font-medium whitespace-nowrap bg-gray-100 text-gray-500">
                          Image: {variantMapping.image_filename}
                        </div>
                      )}
                    </div>
                  </div>
                  <div className="flex items-center space-x-2">
                    {!readOnly && (
                      <>
                        {variantMapping.image_filename ? (
                          <span className="inline-flex items-center rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800">
                            <SvgIcon
                              name="CheckIcon"
                              className="w-4 h-4 mr-1"
                            />
                            Ready
                          </span>
                        ) : (
                          <span className="inline-flex items-center rounded-full bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-800">
                            <SvgIcon
                              name="AlertCircleIcon"
                              className="w-4 h-4 mr-1"
                            />
                            Missing Image
                          </span>
                        )}
                      </>
                    )}
                    {!readOnly && (
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
                    )}
                  </div>
                </div>
                ) : (
                  <div className="flex items-center justify-between mt-4 p-3 bg-orange-50 rounded-sm">
                    <div className="flex items-center space-x-2">
                      {!readOnly && (
                        <button
                          onClick={() => setIsModalOpen(true)}
                          className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-slate-800 bg-white hover:bg-slate-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-950 transition-colors"
                        >
                          <i className="fa-solid fa-search w-3 h-3 mr-2 "></i>
                          Choose product & image
                        </button>
                      )}
                    </div>
                    <div className="text-sm font-medium text-slate-900">
                      No product or image selected
                    </div>
                  </div>
                )
              )}
            </>
          )}
        </div>
      </div>

      {/* Product Select Modal */}
      <ProductSelectModal
        isOpen={isModalOpen}
        onRequestClose={() => {
          setIsModalOpen(false);
          setReplaceImageMode(false);
          setCurrentSlotPosition(null);
        }}
        productVariantId={item.product_variant_id || null}
        orderItemId={item.id}
        slotPosition={currentSlotPosition}
        apiUrl={apiUrl}
        countryCode={countryCode}
        replaceImageMode={replaceImageMode}
        existingVariantMapping={
          isBundle && currentSlotPosition
            ? getMappingForSlot(currentSlotPosition)
            : (replaceImageMode ? variantMapping : null)
        }
        productTypeImages={productTypeImages}
        onProductSelect={(selection) => {
          if (selection.variantMapping) {
            setVariantMapping(selection.variantMapping);
            setImageLoading(true);
            console.log("Variant mapping created:", selection.variantMapping);
            // Refresh the page to reflect the updated order state
            window.location.reload();
          }
          setCurrentSlotPosition(null);
        }}
      />

      {/* Lightbox for image preview (single mapping) */}
      {!isBundle && variantMapping && variantMapping.framed_preview_thumbnail && (
        <Lightbox
          isOpen={isLightboxOpen}
          imageUrl={
            variantMapping.framed_preview_large ||
            variantMapping.framed_preview_thumbnail
          }
          thumbnailUrl={variantMapping.framed_preview_thumbnail}
          imageAlt={item.display_name}
          onClose={() => setIsLightboxOpen(false)}
        />
      )}

      {/* Lightbox for bundle slot images */}
      {isBundle && bundleSlotLightboxOpen && (() => {
        const mapping = getMappingForSlot(bundleSlotLightboxOpen);
        return mapping?.framed_preview_thumbnail ? (
          <Lightbox
            isOpen={true}
            imageUrl={
              mapping.framed_preview_large ||
              mapping.framed_preview_thumbnail
            }
            thumbnailUrl={mapping.framed_preview_thumbnail}
            imageAlt={`${item.display_name} - Slot ${bundleSlotLightboxOpen}`}
            onClose={() => setBundleSlotLightboxOpen(null)}
          />
        ) : null;
      })()}
    </div>
  );
}

export default OrderItemCard;
