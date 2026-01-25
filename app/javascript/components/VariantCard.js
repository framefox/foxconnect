import React, { useState, useEffect, useRef } from "react";
import axios from "axios";
import ProductSelectModal from "./ProductSelectModal";
import { SvgIcon, Lightbox } from "../components";

function VariantCard({
  variant,
  storeId, // This is actually the store UID (keeping the prop name for backwards compatibility)
  storePlatform = "shopify", // Platform of the store (shopify, squarespace, wix, etc.)
  onToggle,
  onMappingChange,
  productTypeImages = {},
  bundlesEnabled = false, // Controls whether bundle size controls are shown
}) {
  // Capitalize platform name for display
  const platformDisplayName =
    storePlatform.charAt(0).toUpperCase() + storePlatform.slice(1);
  const [isActive, setIsActive] = useState(variant.fulfilment_active);
  const [isLoading, setIsLoading] = useState(false);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentSlotPosition, setCurrentSlotPosition] = useState(null);
  const [imageLoading, setImageLoading] = useState(true);

  // Bundle support - check if variant has bundle with multiple slots
  const bundle = variant.bundle || null;
  const isBundle = bundle && bundle.slot_count > 1;

  // For bundles, use bundle.variant_mappings array; for single, use variant.variant_mapping
  const [bundleMappings, setBundleMappings] = useState(
    bundle?.variant_mappings || [],
  );
  const [variantMapping, setVariantMapping] = useState(
    variant.variant_mapping || null,
  );

  const [isSyncing, setIsSyncing] = useState(false);
  const [showDropdown, setShowDropdown] = useState(false);
  const [dropdownPosition, setDropdownPosition] = useState({
    top: 0,
    right: 0,
  });
  const [isLightboxOpen, setIsLightboxOpen] = useState(false);
  const [bundleSlotLightboxOpen, setBundleSlotLightboxOpen] = useState(null); // Tracks which bundle slot's lightbox is open
  const [replaceImageMode, setReplaceImageMode] = useState(false);
  const [bundleSlotDropdownOpen, setBundleSlotDropdownOpen] = useState(null); // Tracks which slot's dropdown is open (slot position)
  const [bundleSlotDropdownPosition, setBundleSlotDropdownPosition] = useState({
    top: 0,
    right: 0,
  });
  const [showApplyImageModal, setShowApplyImageModal] = useState(false);
  const [isApplyingImage, setIsApplyingImage] = useState(false);
  const [applyImageSlotPosition, setApplyImageSlotPosition] = useState(null);
  const [bundleSlotImageLoading, setBundleSlotImageLoading] = useState({}); // Tracks loading state per slot position
  const imageRef = useRef(null);
  const loadingTimeoutRef = useRef(null);
  const variantIdRef = useRef(null); // Track variant ID to detect when we switch variants

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

  // Helper functions for bundle support
  const getMappingForSlot = (slotPosition) => {
    return bundleMappings.find((m) => m.slot_position === slotPosition) || null;
  };

  const calculateTotalFrameCost = () => {
    if (isBundle) {
      return bundleMappings.reduce((total, mapping) => {
        return total + (mapping?.frame_sku_cost_dollars || 0);
      }, 0);
    }
    return variantMapping?.frame_sku_cost_dollars || 0;
  };

  const handleSlotClick = (slotPosition) => {
    setCurrentSlotPosition(slotPosition);
    const mapping = getMappingForSlot(slotPosition);
    setReplaceImageMode(!!mapping);
    setIsModalOpen(true);
  };

  const handleBundleMappingUpdate = (slotPosition, newMapping) => {
    setBundleMappings((prev) => {
      const filtered = prev.filter((m) => m.slot_position !== slotPosition);
      if (newMapping) {
        const updatedMappings = [
          ...filtered,
          { ...newMapping, slot_position: slotPosition },
        ].sort((a, b) => a.slot_position - b.slot_position);
        return updatedMappings;
      }
      return filtered;
    });
  };

  // Update local state when parent state changes
  useEffect(() => {
    setIsActive(variant.fulfilment_active);
    setVariantMapping(variant.variant_mapping || null);
    if (variant.variant_mapping) {
      setImageLoading(true);
    }
  }, [variant.fulfilment_active, variant.variant_mapping]);

  // Update bundle mappings only when viewing a different variant (preserve local updates)
  useEffect(() => {
    // Check if we're viewing a different variant or if this is the first render
    if (variantIdRef.current !== variant.id) {
      setBundleMappings(variant.bundle?.variant_mappings || []);
      variantIdRef.current = variant.id;
    }
  }, [variant.id, variant.bundle]);

  // Reset image loading when variant mapping changes with timeout fallback
  useEffect(() => {
    if (variantMapping && variantMapping.framed_preview_thumbnail) {
      setImageLoading(true);

      // Check if image is already loaded (cached)
      if (imageRef.current && imageRef.current.complete) {
        setImageLoading(false);
      }

      // Fallback timeout to prevent getting stuck in loading state
      loadingTimeoutRef.current = setTimeout(() => {
        setImageLoading(false);
      }, 3000); // 3 second timeout
    }

    // Cleanup timeout on unmount or when dependencies change
    return () => {
      if (loadingTimeoutRef.current) {
        clearTimeout(loadingTimeoutRef.current);
      }
    };
  }, [variantMapping?.framed_preview_thumbnail]);

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

  // Bundle slot image loading handlers
  const handleBundleSlotImageLoad = (slotPosition) => {
    setBundleSlotImageLoading((prev) => ({ ...prev, [slotPosition]: false }));
  };

  const handleBundleSlotImageError = (slotPosition) => {
    setBundleSlotImageLoading((prev) => ({ ...prev, [slotPosition]: false }));
  };

  const isBundleSlotImageLoading = (slotPosition) => {
    return bundleSlotImageLoading[slotPosition] !== false;
  };

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
        },
      );

      if (response.data.success) {
        const newState = response.data.fulfilment_active;
        setIsActive(newState);
        // Notify parent of state change
        if (onToggle) {
          onToggle(variant.id, newState);
        }
      }
    } catch (error) {
      // Handle error silently or show user-friendly message if needed
    } finally {
      setIsLoading(false);
    }
  };

  const handleRemoveMapping = async () => {
    if (!variantMapping || !variantMapping.id) {
      setVariantMapping(null);
      if (onMappingChange) {
        onMappingChange(variant.id, null);
      }
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
      if (onMappingChange) {
        onMappingChange(variant.id, null);
      }
    } catch (error) {
      // You might want to show an error message to the user here
    }
  };

  const handleRemoveBundleMapping = async (slotPosition) => {
    const mapping = getMappingForSlot(slotPosition);

    if (!mapping || !mapping.id) {
      // If no mapping exists, just close dropdown
      setBundleSlotDropdownOpen(null);
      return;
    }

    try {
      await axios.delete(`/variant_mappings/${mapping.id}`, {
        headers: {
          "Content-Type": "application/json",
          "X-Requested-With": "XMLHttpRequest",
          "X-CSRF-Token": document
            .querySelector('meta[name="csrf-token"]')
            .getAttribute("content"),
        },
      });

      // Remove the mapping from the local state
      const updatedMappings = bundleMappings.filter(
        (m) => m.slot_position !== slotPosition,
      );
      setBundleMappings(updatedMappings);
    } catch (error) {
      const errorMessage =
        error.response?.data?.error ||
        error.message ||
        "Failed to remove mapping";
      alert(`Failed to remove mapping: ${errorMessage}`);
    } finally {
      setBundleSlotDropdownOpen(null);
    }
  };

  const handleRemoveImage = async () => {
    if (!variantMapping || !variantMapping.id) {
      return;
    }

    try {
      const response = await axios.delete(
        `/variant_mappings/${variantMapping.id}/remove_image`,
        {
          headers: {
            "Content-Type": "application/json",
            "X-Requested-With": "XMLHttpRequest",
            "X-CSRF-Token": document
              .querySelector('meta[name="csrf-token"]')
              .getAttribute("content"),
          },
        },
      );

      if (response.data.success) {
        // Update the variant mapping to remove image fields
        const updatedMapping = {
          ...variantMapping,
          image_id: null,
          image_key: null,
          cloudinary_id: null,
          image_width: null,
          image_height: null,
          image_filename: null,
          cx: null,
          cy: null,
          cw: null,
          ch: null,
          framed_preview_thumbnail: null,
          framed_preview_medium: null,
          framed_preview_large: null,
          artwork_preview_thumbnail: null,
          artwork_preview_medium: null,
          artwork_preview_large: null,
        };

        setVariantMapping(updatedMapping);
        if (onMappingChange) {
          onMappingChange(variant.id, updatedMapping);
        }
      }
    } catch (error) {
      // Handle error silently or show user-friendly message if needed
    }
  };

  const handleSyncToShopify = async () => {
    if (!variantMapping || !variantMapping.id) {
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
        },
      );

      if (response.data.success) {
        // You could show a success message here
      } else {
        // You could show an error message here
      }
    } catch (error) {
      // You could show an error message here
    } finally {
      setIsSyncing(false);
    }
  };

  const handleApplyImageToAll = async (slotPosition = null) => {
    // Get the correct mapping based on whether this is a bundle slot or single mapping
    const mapping = slotPosition
      ? getMappingForSlot(slotPosition)
      : variantMapping;

    if (!mapping?.id) {
      return;
    }

    setIsApplyingImage(true);

    try {
      const response = await axios.post(
        `/variant_mappings/${mapping.id}/apply_image_to_all`,
        {},
        {
          headers: {
            "Content-Type": "application/json",
            "X-Requested-With": "XMLHttpRequest",
            "X-CSRF-Token": document
              .querySelector('meta[name="csrf-token"]')
              .getAttribute("content"),
          },
        },
      );

      if (response.data.success) {
        setShowApplyImageModal(false);
        setApplyImageSlotPosition(null);
        // Reload the page to show updated mappings
        window.location.reload();
      } else {
        alert(response.data.error || "Failed to apply image to all variants");
      }
    } catch (error) {
      const errorMessage =
        error.response?.data?.error || error.message || "Failed to apply image";
      alert(errorMessage);
    } finally {
      setIsApplyingImage(false);
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
                className={`inline-flex items-center rounded-lg px-2.5 py-1.5 text-xs font-medium whitespace-nowrap ${
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
                className={`relative inline-flex h-6.5 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 ${
                  isActive ? "bg-blue-800" : "bg-gray-200"
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
            (isBundle ? bundleMappings.length > 0 : variantMapping)
              ? "bg-slate-50 border-t border-slate-200"
              : "bg-orange-50 border-t border-orange-100"
          } p-6`}
        >
          <div className="">
            {/* Info message for non-bundle with no mapping */}
            {!isBundle && !variantMapping && (
              <p className="text-slate-700 text-sm mb-4">
                Add a product and an image to have Framefox fulfil this item
                automatically.
              </p>
            )}

            {/* Info message for bundle with no mappings */}
            {isBundle && bundleMappings.length === 0 && (
              <p className="text-slate-700 text-sm mb-4">
                This is a {bundle.slot_count}-item bundle. Configure each slot
                with a product and image.
              </p>
            )}

            <div className="space-y-3">
              {/* Bundle Slots Grid */}
              {isBundle ? (
                <>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                    {Array.from(
                      { length: bundle.slot_count },
                      (_, i) => i + 1,
                    ).map((slotPosition) => {
                      const mapping = getMappingForSlot(slotPosition);

                      return (
                        <div
                          key={slotPosition}
                          className="bg-white rounded-md p-3 border border-slate-200"
                        >
                          {/* Slot Header */}
                          <div className="flex items-center justify-between mb-3">
                            <span className="inline-flex items-center rounded-lg bg-slate-100 px-2 py-1 text-xs font-semibold text-slate-700">
                              Slot {slotPosition}
                            </span>
                            {mapping && (
                              <button
                                onClick={(e) => {
                                  const rect =
                                    e.currentTarget.getBoundingClientRect();
                                  setBundleSlotDropdownPosition({
                                    top: rect.bottom + window.scrollY + 4,
                                    right:
                                      window.innerWidth -
                                      rect.right -
                                      window.scrollX,
                                  });
                                  setBundleSlotDropdownOpen(
                                    bundleSlotDropdownOpen === slotPosition
                                      ? null
                                      : slotPosition,
                                  );
                                }}
                                className="inline-flex items-center px-2 py-1 text-xs leading-4 font-medium rounded text-slate-700 bg-white hover:bg-slate-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 transition-colors"
                                title="More options"
                              >
                                <i className="fa-solid fa-ellipsis w-3 h-3"></i>
                              </button>
                            )}
                          </div>

                          {/* Slot Content */}
                          {mapping ? (
                            <div className="flex items-start space-x-3">
                              {mapping.framed_preview_thumbnail ? (
                                <div
                                  className="w-20 h-20 flex-shrink-0 rounded overflow-hidden cursor-pointer group relative flex items-center justify-center"
                                  onClick={() =>
                                    setBundleSlotLightboxOpen(slotPosition)
                                  }
                                  title="Click to view larger image"
                                >
                                  {isBundleSlotImageLoading(slotPosition) && (
                                    <div className="absolute inset-0 flex items-center justify-center bg-gray-50 rounded">
                                      <i className="fa-solid fa-spinner-third fa-spin text-gray-400 text-sm"></i>
                                    </div>
                                  )}
                                  <img
                                    src={mapping.framed_preview_thumbnail}
                                    alt={`Slot ${slotPosition}`}
                                    className={`${
                                      mapping.ch > mapping.cw
                                        ? "h-full"
                                        : "w-full"
                                    } object-contain ${
                                      isBundleSlotImageLoading(slotPosition)
                                        ? "opacity-0"
                                        : "opacity-100"
                                    } transition-opacity duration-200`}
                                    onLoad={() =>
                                      handleBundleSlotImageLoad(slotPosition)
                                    }
                                    onError={() =>
                                      handleBundleSlotImageError(slotPosition)
                                    }
                                  />
                                  {/* Zoom overlay indicator */}
                                  <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-all duration-200 rounded flex items-center justify-center">
                                    <SvgIcon
                                      name="ViewIcon"
                                      className="w-4 h-4 text-white opacity-0 group-hover:opacity-100 transition-opacity duration-200"
                                    />
                                  </div>
                                </div>
                              ) : (
                                <button
                                  onClick={() => handleSlotClick(slotPosition)}
                                  className="w-20 h-20 flex-shrink-0 flex flex-col items-center justify-center bg-amber-50 rounded hover:bg-amber-100 transition-all cursor-pointer group"
                                  title="Click to add image"
                                >
                                  <SvgIcon
                                    name="PlusCircleIcon"
                                    className="w-4 h-4 text-amber-600 group-hover:text-amber-700 mb-0.5 transition-colors"
                                  />
                                  <p className="text-[10px] text-amber-600 font-medium group-hover:text-amber-700 transition-colors">
                                    Add image
                                  </p>
                                </button>
                              )}
                              <div className="flex-1 min-w-0">
                                <p className="text-sm font-medium text-slate-900 truncate">
                                  {mapping.frame_sku_title}
                                </p>

                                {mapping.frame_sku_description && (
                                  <div className="mt-1.5 flex flex-wrap gap-1">
                                    {mapping.frame_sku_description
                                      .split("|")
                                      .map((part, index) => (
                                        <span
                                          className="inline-flex items-center rounded px-1.5 py-0.5 text-[10px] font-medium whitespace-nowrap bg-gray-100 text-gray-500"
                                          key={index}
                                        >
                                          {part.trim()}
                                        </span>
                                      ))}
                                  </div>
                                )}
                                <p className="text-xs text-slate-600 font-medium mt-1">
                                  {mapping.frame_sku_cost_formatted}
                                </p>
                                {mapping.image_filename && (
                                  <p className="text-xs text-slate-400 mt-1 truncate">
                                    {mapping.image_filename}
                                  </p>
                                )}
                              </div>
                            </div>
                          ) : (
                            <button
                              onClick={() => handleSlotClick(slotPosition)}
                              className="w-full h-24 flex flex-col items-center justify-center bg-orange-50 border-1  border-orange-100 rounded hover:bg-orange-50 hover:border-orange-200 transition-all cursor-pointer group"
                            >
                              <SvgIcon
                                name="PlusCircleIcon"
                                className="w-5 h-5 text-gray-800 group-hover:text-orange-700 mb-1 transition-colors"
                              />
                              <p className="text-xs text-gray-800 font-medium group-hover:text-orange-700 transition-colors">
                                Add to Slot {slotPosition}
                              </p>
                            </button>
                          )}

                          {/* Bundle Slot Dropdown Menu */}
                          {bundleSlotDropdownOpen === slotPosition && (
                            <>
                              {/* Backdrop to close dropdown */}
                              <div
                                className="fixed inset-0 z-40"
                                onClick={() => setBundleSlotDropdownOpen(null)}
                              />
                              {/* Dropdown menu */}
                              <div
                                className="fixed w-56 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 z-50"
                                style={{
                                  top: `${bundleSlotDropdownPosition.top}px`,
                                  right: `${bundleSlotDropdownPosition.right}px`,
                                }}
                              >
                                <div className="py-1" role="menu">
                                  <button
                                    onClick={() => {
                                      setBundleSlotDropdownOpen(null);
                                      setCurrentSlotPosition(slotPosition);
                                      setReplaceImageMode(true);
                                      setIsModalOpen(true);
                                    }}
                                    className="flex items-center w-full px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 hover:text-slate-900 transition-colors"
                                    role="menuitem"
                                  >
                                    <SvgIcon
                                      name="ReplaceIcon"
                                      className="w-4.5 h-4.5 mr-3"
                                    />
                                    Replace image
                                  </button>

                                  {mapping.image_filename && (
                                    <button
                                      onClick={() => {
                                        setBundleSlotDropdownOpen(null);
                                        setApplyImageSlotPosition(slotPosition);
                                        setShowApplyImageModal(true);
                                      }}
                                      className="flex items-center w-full px-4 py-2 text-sm text-left text-slate-700 hover:bg-slate-50 hover:text-slate-900 transition-colors"
                                      role="menuitem"
                                    >
                                      <SvgIcon
                                        name="DuplicateIcon"
                                        className="w-4.5 h-4.5 mr-3 flex-shrink-0"
                                      />
                                      Apply image to all variants in Slot{" "}
                                      {slotPosition}
                                    </button>
                                  )}

                                  <button
                                    onClick={() => {
                                      handleRemoveBundleMapping(slotPosition);
                                    }}
                                    className="flex items-center w-full px-4 py-2 text-sm text-red-700 hover:bg-red-50 hover:text-red-900 transition-colors"
                                    role="menuitem"
                                  >
                                    <SvgIcon
                                      name="DeleteIcon"
                                      className="w-4.5 h-4.5 mr-3"
                                    />
                                    Remove product & image
                                  </button>
                                </div>
                              </div>
                            </>
                          )}
                        </div>
                      );
                    })}
                  </div>

                  {/* Combined Cost Display */}
                  {bundleMappings.length > 0 && (
                    <div className="bg-white rounded-md p-3 border border-slate-200">
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-medium text-slate-700">
                          Bundle Cost ({bundleMappings.length} of{" "}
                          {bundle.slot_count} configured):
                        </span>
                        <span className="text-sm font-semibold text-slate-900">
                          ${calculateTotalFrameCost().toFixed(2)}
                        </span>
                      </div>
                    </div>
                  )}
                </>
              ) : (
                /* Single mapping (non-bundle or single-slot bundle) */
                <>
                  {variantMapping && (
                    <div className="bg-white rounded-md p-3">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-5">
                          {variantMapping.framed_preview_thumbnail ? (
                            <div className="flex-shrink-0 flex flex-col items-center">
                              <div
                                className="w-36 h-36 flex items-center justify-center relative cursor-pointer group"
                                onClick={() => setIsLightboxOpen(true)}
                                title="Click to view larger image"
                              >
                                {imageLoading && (
                                  <div className="absolute inset-0 flex items-center justify-center bg-gray-50 rounded">
                                    <i className="fa-solid fa-spinner-third fa-spin text-gray-400"></i>
                                  </div>
                                )}
                                <img
                                  ref={imageRef}
                                  src={variantMapping.framed_preview_thumbnail}
                                  alt="Framed artwork preview"
                                  className={`${
                                    variantMapping.ch > variantMapping.cw
                                      ? "h-full"
                                      : "w-full"
                                  } object-contain ${
                                    imageLoading ? "opacity-0" : "opacity-100"
                                  } transition-opacity duration-200`}
                                  onLoad={handleImageLoad}
                                  onError={handleImageError}
                                />
                                {/* Zoom overlay indicator */}
                                <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-all duration-200 rounded flex items-center justify-center">
                                  <SvgIcon
                                    name="ViewIcon"
                                    className="w-8 h-8 text-white opacity-0 group-hover:opacity-100 transition-opacity duration-200"
                                  />
                                </div>
                              </div>
                              {(() => {
                                const dpi = calculateDPI(variantMapping);
                                if (dpi !== null) {
                                  if (dpi < 125) {
                                    return (
                                      <div className="mt-2 flex items-center space-x-2">
                                        <div className="inline-flex items-center rounded-lg px-2 py-1 text-xs font-medium whitespace-nowrap bg-amber-50 text-amber-500">
                                          Low: {dpi} DPI
                                        </div>
                                        <button
                                          onClick={() => {
                                            setReplaceImageMode(true);
                                            setIsModalOpen(true);
                                          }}
                                          className="inline-flex items-center text-xs text-gray-500 hover:text-gray-700 underline transition-colors"
                                        >
                                          <SvgIcon
                                            name="ReplaceIcon"
                                            className="w-3 h-3 mr-1"
                                          />
                                          Replace
                                        </button>
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
                          ) : (
                            <button
                              onClick={() => {
                                setReplaceImageMode(true);
                                setIsModalOpen(true);
                              }}
                              className="w-36 h-36 flex-shrink-0 flex flex-col items-center justify-center bg-amber-50  border-amber-300 rounded hover:bg-amber-100 hover:border-amber-200 transition-all cursor-pointer group"
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
                          )}

                          <div className="flex-1">
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
                                  <div className="inline-flex items-center rounded-lg px-2 py-1 text-xs font-medium whitespace-nowrap bg-gray-100 text-gray-500 mr-2 mb-2">
                                    Image: {variantMapping.image_filename}
                                  </div>
                                )}
                              </div>
                            </div>
                            <div className="text-xs text-gray-400 mt-1">
                              {variantMapping.frame_sku_cost_formatted}
                            </div>
                          </div>
                        </div>
                        <div className="relative">
                          <button
                            onClick={(e) => {
                              const rect =
                                e.currentTarget.getBoundingClientRect();
                              setDropdownPosition({
                                top: rect.bottom + window.scrollY + 4,
                                right:
                                  window.innerWidth -
                                  rect.right -
                                  window.scrollX,
                              });
                              setShowDropdown(!showDropdown);
                            }}
                            className="inline-flex items-center px-2 py-1 text-xs leading-4 font-medium rounded text-slate-700 bg-white hover:bg-slate-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 transition-colors"
                            title="More options"
                          >
                            <i className="fa-solid fa-ellipsis w-3 h-3"></i>
                          </button>

                          {showDropdown && (
                            <>
                              {/* Backdrop to close dropdown */}
                              <div
                                className="fixed inset-0 z-40"
                                onClick={() => setShowDropdown(false)}
                              />
                              {/* Dropdown menu */}
                              <div
                                className="fixed w-56 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 z-50"
                                style={{
                                  top: `${dropdownPosition.top}px`,
                                  right: `${dropdownPosition.right}px`,
                                }}
                              >
                                <div className="py-1" role="menu">
                                  {variantMapping.image_filename && (
                                    <>
                                      <button
                                        onClick={() => {
                                          handleSyncToShopify();
                                        }}
                                        disabled={isSyncing}
                                        className={`flex items-center w-full px-4 py-2 text-sm  text-left transition-colors ${
                                          isSyncing
                                            ? "text-blue-800 bg-blue-50 cursor-not-allowed"
                                            : "text-slate-700 hover:bg-slate-50 hover:text-slate-900"
                                        }`}
                                        role="menuitem"
                                      >
                                        {isSyncing ? (
                                          <>
                                            <i className="fa-solid fa-spinner-third fa-spin w-4 h-4 mr-3"></i>
                                            Syncing to {platformDisplayName}...
                                          </>
                                        ) : (
                                          <>
                                            <SvgIcon
                                              name="ImageMagicIcon"
                                              className="w-4.5 h-4.5 mr-3"
                                            />
                                            Sync mockup image to{" "}
                                            {platformDisplayName}
                                          </>
                                        )}
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
                                        <SvgIcon
                                          name="ReplaceIcon"
                                          className="w-4.5 h-4.5 mr-3"
                                        />
                                        Replace image
                                      </button>
                                      <button
                                        onClick={() => {
                                          setShowDropdown(false);
                                          handleRemoveImage();
                                        }}
                                        className="flex items-center w-full px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 hover:text-slate-900 transition-colors"
                                        role="menuitem"
                                      >
                                        <SvgIcon
                                          name="DeleteIcon"
                                          className="w-4.5 h-4.5 mr-3"
                                        />
                                        Remove image
                                      </button>
                                      <button
                                        onClick={() => {
                                          setShowDropdown(false);
                                          setShowApplyImageModal(true);
                                        }}
                                        className="flex items-center w-full px-4 py-2 text-sm text-left text-slate-700 hover:bg-slate-50 hover:text-slate-900 transition-colors"
                                        role="menuitem"
                                      >
                                        <SvgIcon
                                          name="DuplicateIcon"
                                          className="w-4.5 h-4.5 mr-3 flex-shrink-0"
                                        />
                                        Apply image to all variants
                                      </button>

                                      {/* Separator */}
                                      <div className="border-t border-slate-200 my-1"></div>
                                    </>
                                  )}

                                  <button
                                    onClick={() => {
                                      setShowDropdown(false);
                                      handleRemoveMapping();
                                    }}
                                    className="flex items-center w-full px-4 py-2 text-sm text-red-700 hover:bg-red-50 hover:text-red-900 transition-colors"
                                    role="menuitem"
                                  >
                                    <SvgIcon
                                      name="DeleteIcon"
                                      className="w-4.5 h-4.5 mr-3"
                                    />
                                    Remove product & image
                                  </button>
                                </div>
                              </div>
                            </>
                          )}
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
                </>
              )}
            </div>
          </div>
        </div>
      )}

      <ProductSelectModal
        isOpen={isModalOpen}
        onRequestClose={() => {
          setIsModalOpen(false);
          setReplaceImageMode(false);
          setCurrentSlotPosition(null);
        }}
        productVariantId={variant.id}
        productVariantTitle={variant.title}
        bundleId={isBundle ? bundle.id : null}
        slotPosition={currentSlotPosition}
        productTypeImages={productTypeImages}
        replaceImageMode={replaceImageMode}
        existingVariantMapping={
          isBundle && currentSlotPosition
            ? getMappingForSlot(currentSlotPosition)
            : replaceImageMode
              ? variantMapping
              : null
        }
        onProductSelect={(selection) => {
          // The selection now contains the full variantMapping from the backend
          if (selection.variantMapping) {
            if (isBundle && currentSlotPosition) {
              // Update bundle mapping for specific slot
              handleBundleMappingUpdate(
                currentSlotPosition,
                selection.variantMapping,
              );
            } else {
              // Update single mapping
              setVariantMapping(selection.variantMapping);
            }

            if (onMappingChange) {
              onMappingChange(variant.id, selection.variantMapping);
            }
          }
          setReplaceImageMode(false);
          setCurrentSlotPosition(null);
        }}
      />

      {/* Lightbox for image preview (single mapping) */}
      {variantMapping && variantMapping.framed_preview_thumbnail && (
        <Lightbox
          isOpen={isLightboxOpen}
          imageUrl={
            variantMapping.framed_preview_large ||
            variantMapping.framed_preview_thumbnail
          }
          thumbnailUrl={variantMapping.framed_preview_thumbnail}
          imageAlt="Framed artwork preview"
          onClose={() => setIsLightboxOpen(false)}
        />
      )}

      {/* Lightbox for bundle slot images */}
      {isBundle &&
        bundleSlotLightboxOpen &&
        (() => {
          const mapping = getMappingForSlot(bundleSlotLightboxOpen);
          return mapping?.framed_preview_thumbnail ? (
            <Lightbox
              isOpen={true}
              imageUrl={
                mapping.framed_preview_large || mapping.framed_preview_thumbnail
              }
              thumbnailUrl={mapping.framed_preview_thumbnail}
              imageAlt={`Slot ${bundleSlotLightboxOpen} - ${mapping.frame_sku_title}`}
              onClose={() => setBundleSlotLightboxOpen(null)}
            />
          ) : null;
        })()}

      {/* Apply Image to All Variants Confirmation Modal */}
      {showApplyImageModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center">
          {/* Backdrop */}
          <div
            className="absolute inset-0 bg-black opacity-50"
            onClick={() => {
              if (!isApplyingImage) {
                setShowApplyImageModal(false);
                setApplyImageSlotPosition(null);
              }
            }}
          />
          {/* Modal */}
          <div className="relative bg-white rounded-lg shadow-xl max-w-md w-full mx-4 p-6">
            <h3 className="text-lg font-semibold text-slate-900 mb-4">
              {applyImageSlotPosition
                ? `Apply image to all variants in Slot ${applyImageSlotPosition}`
                : "Apply image and cropping to all variants"}
            </h3>
            <p className="text-sm text-slate-600 mb-6">
              {applyImageSlotPosition
                ? `This will apply the current image and crop settings to Slot ${applyImageSlotPosition} of all other variants.`
                : "This will apply the current image and crop settings to all other variants in this product."}
            </p>
            <div className="bg-amber-50 border border-amber-200 rounded-lg p-4 mb-6">
              <div className="flex">
                <div className="flex-shrink-0">
                  <SvgIcon
                    name="AlertTriangleIcon"
                    className="w-5 h-5 text-amber-600"
                  />
                </div>
                <div className="ml-3">
                  <p className="text-sm text-amber-800">
                    Only do this if all your prints have the same aspect ratio
                    e.g. A4 / A3 / A2
                  </p>
                </div>
              </div>
            </div>

            <div className="flex justify-end space-x-3">
              <button
                onClick={() => {
                  setShowApplyImageModal(false);
                  setApplyImageSlotPosition(null);
                }}
                disabled={isApplyingImage}
                className="px-4 py-2 text-sm font-medium text-slate-700 bg-white border border-slate-300 rounded-md hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                onClick={() => handleApplyImageToAll(applyImageSlotPosition)}
                disabled={isApplyingImage}
                className="px-4 py-2 text-sm font-medium text-white bg-slate-900 rounded-md hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500 disabled:opacity-50 flex items-center"
              >
                {isApplyingImage && (
                  <i className="fa-solid fa-spinner-third fa-spin mr-2"></i>
                )}
                Continue
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default VariantCard;
