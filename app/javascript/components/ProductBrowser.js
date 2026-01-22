import React, { useState, useEffect } from "react";
import CustomPrintSizeModal from "./CustomPrintSizeModal";
import SvgIcon from "./SvgIcon";

function ProductBrowser({ productTypeImages = {} }) {
  const [currentStep, setCurrentStep] = useState("type-selection");
  const [selectedProductType, setSelectedProductType] = useState(null);
  const [frameSkuData, setFrameSkuData] = useState(null);
  const [frameSkuLoading, setFrameSkuLoading] = useState(false);
  const [frameSkuError, setFrameSkuError] = useState(null);
  const [selectedOptions, setSelectedOptions] = useState({
    mat_style: "",
    glass_type: "",
    paper_type: "",
    frame_style_colour: "",
    frame_sku_size: "",
  });
  const [selectedCollection, setSelectedCollection] = useState(null);
  const [searchResults, setSearchResults] = useState(null);
  const [searchLoading, setSearchLoading] = useState(false);
  const [searchError, setSearchError] = useState(null);
  const [selectedCountry, setSelectedCountry] = useState("NZ");
  const [customSizeModalOpen, setCustomSizeModalOpen] = useState(false);
  const [customSizes, setCustomSizes] = useState([]);
  const [customSizesLoading, setCustomSizesLoading] = useState(false);
  const [loadingProductType, setLoadingProductType] = useState(null);

  // Saved items state
  const [savedFrameSkuIds, setSavedFrameSkuIds] = useState([]);
  const [savedItems, setSavedItems] = useState([]);
  const [savedItemsLoading, setSavedItemsLoading] = useState(false);
  const [savedItemsError, setSavedItemsError] = useState(null);
  const [savedItemsFilters, setSavedItemsFilters] = useState({
    printSize: "",
    frameStyle: "",
    paperType: "",
    matBorder: "",
    glassType: "",
  });

  // Supported countries
  const supportedCountries = [
    { code: "NZ", name: "New Zealand", currency: "NZD" },
    { code: "AU", name: "Australia", currency: "AUD" },
  ];

  // Product type configurations
  const productTypes = [
    {
      id: "matted",
      label: "Print, Frame & Mat Border",
      image: productTypeImages.matted,
      endpoint: "matted.json",
    },
    {
      id: "unmatted",
      label: "Print, Frame & No Mat",
      image: productTypeImages.unmatted,
      endpoint: "unmatted.json",
    },
    {
      id: "canvas",
      label: "Canvas Print & Frame",
      image: productTypeImages.canvas,
      endpoint: "canvas.json",
    },
    {
      id: "print-only",
      label: "Print Only (Unframed)",
      image: productTypeImages.printOnly,
      endpoint: "unframed.json",
    },
  ];

  // Get the base API URL based on selected country
  const getApiUrl = () => {
    // Validate configuration exists
    if (!window.FramefoxConfig || !window.FramefoxConfig.apiUrl) {
      console.warn("FramefoxConfig not available, API calls may fail");
      return null;
    }

    // Use the configured API URL from the backend
    return window.FramefoxConfig.apiUrl;
  };

  // Get the API auth token
  const getApiAuthToken = () => {
    return window.FramefoxConfig?.apiAuthToken || null;
  };

  // Helper function to add auth parameter to URL
  const addAuthToUrl = (url) => {
    const authToken = getApiAuthToken();
    if (!authToken) {
      console.warn("API auth token not available");
      return url;
    }
    const separator = url.includes("?") ? "&" : "?";
    return `${url}${separator}auth=${authToken}`;
  };

  // Fetch custom print sizes for current user
  const fetchCustomSizes = async () => {
    setCustomSizesLoading(true);
    try {
      const response = await fetch("/custom_print_sizes.json");
      if (response.ok) {
        const data = await response.json();
        setCustomSizes(data);
      }
    } catch (err) {
      console.error("Failed to fetch custom sizes:", err);
      // Non-critical error, just log it
    } finally {
      setCustomSizesLoading(false);
    }
  };

  // Fetch just the saved IDs (for count display)
  const fetchSavedIds = async () => {
    try {
      const response = await fetch("/saved_items.json");
      if (response.ok) {
        const data = await response.json();
        const savedIds = data.saved_frame_sku_ids || [];
        setSavedFrameSkuIds(savedIds);
      }
    } catch (err) {
      console.error("Failed to fetch saved IDs:", err);
    }
  };

  // Fetch saved items with full details from batch API
  const fetchSavedItems = async () => {
    setSavedItemsLoading(true);
    setSavedItemsError(null);
    try {
      // First, get the saved frame_sku_ids and custom size data from our backend
      const response = await fetch("/saved_items.json");
      if (!response.ok) {
        throw new Error("Failed to load saved items");
      }

      const data = await response.json();
      const savedIds = data.saved_frame_sku_ids || [];
      const savedItemsData = data.saved_items || [];
      console.log("Saved frame SKU IDs:", savedIds);
      console.log("Saved items with custom sizes:", savedItemsData);
      setSavedFrameSkuIds(savedIds);

      // If there are saved IDs, fetch the full frame SKU data from external API
      if (savedIds.length > 0) {
        const baseUrl = getApiUrl();
        const idsParam = savedIds.join(",");
        const batchUrl = addAuthToUrl(
          `${baseUrl}/frame_skus/batch.json?frame_sku_ids=${idsParam}`
        );
        console.log("Fetching from batch API:", batchUrl);

        const batchResponse = await fetch(batchUrl);
        if (!batchResponse.ok) {
          throw new Error("Failed to fetch frame SKU details");
        }

        const batchData = await batchResponse.json();
        console.log("Batch API response:", batchData);

        // Merge frame SKU data with custom size data
        const frameSkus = batchData.frame_skus || [];
        const mergedItems = frameSkus.map((frameSku) => {
          const savedItemData = savedItemsData.find(
            (item) => item.frame_sku_id === frameSku.id
          );
          return {
            ...frameSku,
            custom_print_size: savedItemData?.custom_print_size || null,
          };
        });

        setSavedItems(mergedItems);
      } else {
        setSavedItems([]);
      }
    } catch (err) {
      console.error("Failed to fetch saved items:", err);
      setSavedItemsError(err.message);
    } finally {
      setSavedItemsLoading(false);
    }
  };

  // Toggle saved state for a frame SKU
  const toggleSavedItem = async (frameSkuId, customPrintSizeId = null) => {
    const isSaved = savedFrameSkuIds.includes(frameSkuId);

    // Optimistic update
    if (isSaved) {
      setSavedFrameSkuIds(savedFrameSkuIds.filter((id) => id !== frameSkuId));
      setSavedItems(savedItems.filter((item) => item.id !== frameSkuId));
    } else {
      setSavedFrameSkuIds([...savedFrameSkuIds, frameSkuId]);
    }

    try {
      if (isSaved) {
        // Delete saved item
        const response = await fetch(`/saved_items/${frameSkuId}.json`, {
          method: "DELETE",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token":
              document.querySelector('meta[name="csrf-token"]')?.content || "",
          },
        });

        if (!response.ok) {
          throw new Error("Failed to remove saved item");
        }
      } else {
        // Create saved item with optional custom_print_size_id
        const savedItemData = {
          frame_sku_id: frameSkuId,
        };

        if (customPrintSizeId) {
          savedItemData.custom_print_size_id = customPrintSizeId;
        }

        const response = await fetch("/saved_items.json", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token":
              document.querySelector('meta[name="csrf-token"]')?.content || "",
          },
          body: JSON.stringify({
            saved_item: savedItemData,
          }),
        });

        if (!response.ok) {
          throw new Error("Failed to save item");
        }
      }
    } catch (err) {
      console.error("Error toggling saved item:", err);
      // Revert optimistic update on error
      if (isSaved) {
        setSavedFrameSkuIds([...savedFrameSkuIds, frameSkuId]);
        // If we're on the saved items page, refetch full data
        if (currentStep === "saved-items") {
          fetchSavedItems();
        }
      } else {
        setSavedFrameSkuIds(savedFrameSkuIds.filter((id) => id !== frameSkuId));
      }
    }
  };

  // Fetch saved IDs on mount (just for count display)
  useEffect(() => {
    fetchSavedIds();
  }, []);

  // Refetch saved items when entering saved-items view
  useEffect(() => {
    if (currentStep === "saved-items") {
      fetchSavedItems();
    }
  }, [currentStep]);

  // Fetch frame SKU data when product type is selected
  const fetchFrameSkuData = async (productType) => {
    setFrameSkuLoading(true);
    setFrameSkuError(null);
    setLoadingProductType(productType);

    try {
      const endpoint = productTypes.find(
        (type) => type.id === productType
      )?.endpoint;
      const baseUrl = getApiUrl();
      const url = addAuthToUrl(`${baseUrl}/frame_skus/${endpoint}`);
      const response = await fetch(url);

      if (!response.ok) {
        throw new Error(
          `Failed to fetch frame SKU data: ${response.statusText}`
        );
      }

      const data = await response.json();
      setFrameSkuData(data);
      setCurrentStep("option-selection");
    } catch (err) {
      setFrameSkuError(err.message);
    } finally {
      setFrameSkuLoading(false);
      setLoadingProductType(null);
    }
  };

  const handleProductTypeSelect = (productType) => {
    setSelectedProductType(productType);
    fetchFrameSkuData(productType);
    fetchCustomSizes(); // Fetch custom sizes when product type is selected
  };

  // Search frame SKUs based on selected options
  const searchFrameSkus = async (options) => {
    setSearchLoading(true);
    setSearchError(null);

    try {
      // Build query parameters, only including non-empty values
      const params = new URLSearchParams();

      if (options.paper_type) {
        params.append("paper_type_id", options.paper_type);
      }
      if (options.glass_type) {
        params.append("glass_type_id", options.glass_type);
      }
      if (options.mat_style) {
        params.append("mat_style_id", options.mat_style);
      }
      if (options.frame_style_colour) {
        params.append("frame_style_colour_id", options.frame_style_colour);
      }
      if (options.frame_sku_size) {
        params.append("frame_sku_size_id", options.frame_sku_size);
      }

      const baseUrl = getApiUrl();
      const urlWithParams = `${baseUrl}/frame_skus.json${
        params.toString() ? "?" + params.toString() : ""
      }`;
      const url = addAuthToUrl(urlWithParams);
      const response = await fetch(url);

      if (!response.ok) {
        throw new Error(`Failed to search frame SKUs: ${response.statusText}`);
      }

      const data = await response.json();
      // Extract the frame_skus array from the response
      setSearchResults(data.frame_skus || []);
    } catch (err) {
      setSearchError(err.message);
    } finally {
      setSearchLoading(false);
    }
  };

  const handleOptionChange = (optionType, value) => {
    setSelectedOptions((prev) => ({
      ...prev,
      [optionType]: value,
    }));
  };

  // Auto-search when options change (after initial load)
  useEffect(() => {
    // Only run if frameSkuData is loaded (we're past the initial load)
    if (!frameSkuData || frameSkuLoading || frameSkuError) {
      return;
    }

    // Build the options to search with, handling custom size
    let searchOptions = { ...selectedOptions };
    if (selectedOptions.frame_sku_size?.toString().startsWith("custom-")) {
      const customSizeId = parseInt(
        selectedOptions.frame_sku_size.replace("custom-", "")
      );
      const customSize = customSizes.find((cs) => cs.id === customSizeId);
      if (customSize) {
        searchOptions = {
          ...selectedOptions,
          frame_sku_size: customSize.frame_sku_size_id,
        };
      }
    }

    searchFrameSkus(searchOptions);
  }, [selectedOptions]);

  // Auto-run search with first options when frameSkuData is loaded
  useEffect(() => {
    if (frameSkuData && !frameSkuLoading && !frameSkuError) {
      // Set the first collection as default
      if (
        frameSkuData.frame_style_colours &&
        frameSkuData.frame_style_colours.length > 0
      ) {
        const collections = [
          ...new Set(
            frameSkuData.frame_style_colours
              .map((c) => c.collection)
              .filter(Boolean)
          ),
        ];
        if (collections.length > 0 && !selectedCollection) {
          setSelectedCollection(collections[0]);
        }
      }

      // Build auto-selected options using first item from each available select field
      const autoSelectedOptions = {};

      if (frameSkuData.mat_styles && frameSkuData.mat_styles.length > 0) {
        autoSelectedOptions.mat_style = frameSkuData.mat_styles[0].id;
      }

      if (frameSkuData.glass_types && frameSkuData.glass_types.length > 0) {
        autoSelectedOptions.glass_type = frameSkuData.glass_types[0].id;
      }

      if (frameSkuData.paper_types && frameSkuData.paper_types.length > 0) {
        autoSelectedOptions.paper_type = frameSkuData.paper_types[0].id;
      }

      if (
        frameSkuData.frame_style_colours &&
        frameSkuData.frame_style_colours.length > 0
      ) {
        autoSelectedOptions.frame_style_colour =
          frameSkuData.frame_style_colours[0].id;
      }

      // Don't auto-select print size - let user choose

      // Update selected options state
      setSelectedOptions((prev) => ({
        ...prev,
        ...autoSelectedOptions,
      }));

      // Auto-run search with the first options
      searchFrameSkus(autoSelectedOptions);
    }
  }, [frameSkuData, frameSkuLoading, frameSkuError]);

  const handleBackToTypeSelection = () => {
    setCurrentStep("type-selection");
    setSelectedProductType(null);
    setFrameSkuData(null);
    setFrameSkuError(null);
    setSearchResults(null);
    setSearchError(null);
    setSelectedCollection(null);
    setSelectedOptions({
      mat_style: "",
      glass_type: "",
      paper_type: "",
      frame_style_colour: "",
      frame_sku_size: "",
    });
  };

  const handleBackFromSavedItems = () => {
    setCurrentStep("type-selection");
  };

  const handleOpenCustomSizeModal = () => {
    setCustomSizeModalOpen(true);
  };

  const handleCloseCustomSizeModal = () => {
    setCustomSizeModalOpen(false);
  };

  const handleCustomSizeSubmit = (data) => {
    // Refresh the custom sizes list to include the newly created size
    fetchCustomSizes();

    // Update selected options with a custom size identifier
    // We'll use 'custom-{id}' to distinguish from standard sizes
    const updatedOptions = {
      ...selectedOptions,
      frame_sku_size: `custom-${data.id}`,
    };
    setSelectedOptions(updatedOptions);

    // Close the modal
    setCustomSizeModalOpen(false);

    // Automatically trigger search with the frame_sku_size_id (not the custom prefix)
    searchFrameSkus({
      ...selectedOptions,
      frame_sku_size: data.frame_sku_size_id,
    });
  };

  // Reset product selection when country changes
  useEffect(() => {
    // Only reset if user has already made selections
    if (selectedProductType || frameSkuData) {
      handleBackToTypeSelection();
    }
  }, [selectedCountry]);

  // Helper function to format cents to dollars
  const formatCentsToPrice = (cents) => {
    if (!cents && cents !== 0) return "N/A";
    return `$${(cents / 100).toFixed(2)}`;
  };

  // Get unique filter values from saved items
  const getUniqueFilterValues = (items, field) => {
    if (field === "printSize") {
      // Create a map of size strings to perimeter values for sorting
      const sizeMap = new Map();

      items.forEach((item) => {
        const sizeString = item.custom_print_size
          ? item.custom_print_size.dimensions_display
          : item.title || "No size";

        const perimeter = item.perimeter || 0;

        // Store the smallest perimeter for each unique size string
        if (!sizeMap.has(sizeString) || perimeter < sizeMap.get(sizeString)) {
          sizeMap.set(sizeString, perimeter);
        }
      });

      // Convert to array and sort by perimeter (smallest to largest)
      const sortedSizes = Array.from(sizeMap.entries())
        .filter(([size]) => size && size !== "-")
        .sort((a, b) => a[1] - b[1])
        .map(([size]) => size);

      return sortedSizes;
    }

    const values = items.map((item) => item[field] || "-");
    return [...new Set(values)].filter((v) => v && v !== "-");
  };

  // Filter saved items based on selected filters
  const getFilteredSavedItems = () => {
    return savedItems.filter((item) => {
      if (savedItemsFilters.printSize) {
        const itemSize = item.custom_print_size
          ? item.custom_print_size.dimensions_display
          : item.title || "No size";
        if (itemSize !== savedItemsFilters.printSize) return false;
      }
      if (
        savedItemsFilters.frameStyle &&
        item.frame_style !== savedItemsFilters.frameStyle
      )
        return false;
      if (
        savedItemsFilters.paperType &&
        item.paper_type !== savedItemsFilters.paperType
      )
        return false;
      if (
        savedItemsFilters.matBorder &&
        item.mat_style !== savedItemsFilters.matBorder
      )
        return false;
      if (
        savedItemsFilters.glassType &&
        item.glass_type !== savedItemsFilters.glassType
      )
        return false;
      return true;
    });
  };

  // Reset filters when saved items change
  useEffect(() => {
    setSavedItemsFilters({
      printSize: "",
      frameStyle: "",
      paperType: "",
      matBorder: "",
      glassType: "",
    });
  }, [savedItems]);

  // Get current breadcrumb
  const getBreadcrumb = () => {
    if (currentStep === "saved-items") {
      return "Saved Products";
    } else if (currentStep === "option-selection") {
      const productTypeLabel = productTypes.find(
        (type) => type.id === selectedProductType
      )?.label;
      return productTypeLabel;
    }
    return null;
  };

  // Render product type selection step
  if (currentStep === "type-selection") {
    return (
      <div className="py-8">
        {/* Static Country Display */}
        <div className="flex flex-col items-center justify-center mb-6 gap-1">
          <div className="text-sm font-medium text-gray-700">
            Shipping to{" "}
            {supportedCountries.find((c) => c.code === selectedCountry)?.name ||
              selectedCountry}
          </div>
          <div className="text-xs font-medium text-gray-500">
            (Multi-country support coming soon)
          </div>
        </div>

        <div className="max-w-2xl mx-auto">
          {/* Saved Items Card - Spans Full Width */}
          <button
            onClick={() => {
              setCurrentStep("saved-items");
            }}
            className="w-full mb-6 flex items-center justify-center p-4 border-2 border-gray-200 bg-white rounded-lg hover:border-slate-900 hover:bg-gray-50 transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 cursor-pointer"
          >
            <SvgIcon
              name="StarFilledIcon"
              className="w-6 h-6 text-amber-500 mr-3"
            />
            <span className="font-medium text-gray-900">
              Saved Products ({savedFrameSkuIds.length})
            </span>
          </button>
        </div>
        {/* Product Type Cards - Single Row */}
        <div className="max-w-6xl mx-auto">
          <div className="grid grid-cols-4 gap-6 w-full">
            {productTypes.map((type) => (
              <button
                key={type.id}
                onClick={() => handleProductTypeSelect(type.id)}
                disabled={loadingProductType !== null}
                className="relative flex flex-col items-center justify-center p-4 border-2 border-gray-200 rounded-lg hover:border-slate-900 hover:bg-gray-50 transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 cursor-pointer disabled:cursor-not-allowed disabled:opacity-50"
              >
                {type.image && (
                  <div className="w-full h-48 mb-4 overflow-hidden rounded-md">
                    <img
                      src={type.image}
                      alt={type.label}
                      className="w-full h-full object-cover"
                    />
                  </div>
                )}
                <span className="text-lg font-medium text-gray-900">
                  {type.label}
                </span>
                {loadingProductType === type.id && (
                  <div className="absolute inset-0 bg-white bg-opacity-90 rounded-lg flex items-center justify-center">
                    <i className="fa-solid fa-spinner-third fa-spin text-slate-900 text-3xl"></i>
                  </div>
                )}
              </button>
            ))}
          </div>
        </div>
      </div>
    );
  }

  // Render option selection step
  if (currentStep === "option-selection") {
    return (
      <div className="flex flex-col h-full">
        {/* Breadcrumb Navigation */}
        <div className="mb-4">
          <button
            onClick={handleBackToTypeSelection}
            className="inline-flex items-center text-sm text-gray-600 hover:text-gray-900"
          >
            <SvgIcon name="ChevronLeftIcon" className="w-4 h-4 mr-1" />
            Back to Product Selection
          </button>
          <h2 className="text-2xl font-bold text-gray-900 mt-2">
            {getBreadcrumb()}
          </h2>
        </div>

        {frameSkuLoading && (
          <div className="flex items-center justify-center py-8">
            <i className="fa-solid fa-spinner-third fa-spin text-blue-600 text-2xl"></i>
            <span className="ml-3 text-gray-600">Loading options...</span>
          </div>
        )}

        {frameSkuError && (
          <div className="text-center py-8">
            <div className="text-red-600 mb-2">{frameSkuError}</div>
            <button
              onClick={() => fetchFrameSkuData(selectedProductType)}
              className="px-4 py-2 bg-slate-900 text-slate-50 hover:bg-slate-800 rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 cursor-pointer"
            >
              Try Again
            </button>
          </div>
        )}

        {frameSkuData && !frameSkuLoading && !frameSkuError && (
          <div className="flex-shrink-0 mb-6 space-y-6">
            {/* Frame Style Colours - Visual Selector */}
            {frameSkuData.frame_style_colours &&
              frameSkuData.frame_style_colours.length > 0 && (
                <div>
                  {/* Collection Filter */}
                  {(() => {
                    // Extract unique collections
                    const collections = [
                      ...new Set(
                        frameSkuData.frame_style_colours
                          .map((c) => c.collection)
                          .filter(Boolean)
                      ),
                    ];

                    return collections.length > 1 ? (
                      <div className="flex gap-2 mb-4 flex-wrap">
                        {collections.map((collection) => (
                          <button
                            key={collection}
                            type="button"
                            onClick={() => setSelectedCollection(collection)}
                            className={`px-4 py-2 text-sm font-medium rounded-md transition-colors cursor-pointer ${
                              selectedCollection === collection
                                ? "bg-slate-900 text-white"
                                : "bg-gray-100 text-gray-700 hover:bg-gray-200"
                            }`}
                          >
                            {collection}
                          </button>
                        ))}
                      </div>
                    ) : null;
                  })()}

                  <div className="flex gap-4 overflow-x-auto pb-2">
                    {frameSkuData.frame_style_colours
                      .filter(
                        (colour) =>
                          !selectedCollection ||
                          colour.collection === selectedCollection
                      )
                      .map((colour) => (
                        <button
                          key={colour.id}
                          type="button"
                          onClick={() =>
                            handleOptionChange("frame_style_colour", colour.id)
                          }
                          className={`flex-shrink-0 flex flex-col items-start relative border-1 rounded-lg overflow-hidden transition-all cursor-pointer ${
                            selectedOptions.frame_style_colour === colour.id
                              ? "border-slate-900"
                              : "border-gray-300 hover:border-gray-400"
                          }`}
                        >
                          <div className="w-16 h-16 bg-gray-100 block">
                            <img
                              src={colour.profile}
                              alt={colour.title}
                              className="w-full h-full object-cover"
                            />
                          </div>

                          {selectedOptions.frame_style_colour === colour.id && (
                            <div className="absolute top-1 right-1 bg-slate-900 text-white rounded-full p-1">
                              <svg
                                className="w-3 h-3"
                                fill="currentColor"
                                viewBox="0 0 20 20"
                              >
                                <path
                                  fillRule="evenodd"
                                  d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                                  clipRule="evenodd"
                                />
                              </svg>
                            </div>
                          )}
                        </button>
                      ))}
                  </div>

                  {frameSkuData.frame_style_colours.length > 1 && (
                    <div className="mt-3">
                      <label className="block font-medium text-gray-700">
                        <span className="text-gray-900">
                          {selectedOptions.frame_style_colour
                            ? (() => {
                                const frameStyle =
                                  frameSkuData.frame_style_colours.find(
                                    (c) =>
                                      c.id ===
                                      selectedOptions.frame_style_colour
                                  );
                                return frameStyle ? (
                                  <>
                                    {frameStyle.title}{" "}
                                    <span className="text-xs text-gray-500">
                                      (Width: {frameStyle.width}mm / Depth:{" "}
                                      {frameStyle.depth}mm)
                                    </span>
                                  </>
                                ) : (
                                  "Not selected"
                                );
                              })()
                            : "Not selected"}
                        </span>
                      </label>
                    </div>
                  )}
                </div>
              )}

            {/* Other Options Grid */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
              {/* Mat Styles */}
              {frameSkuData.mat_styles &&
                frameSkuData.mat_styles.length > 0 && (
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Mat Border
                    </label>
                    <select
                      value={selectedOptions.mat_style}
                      onChange={(e) =>
                        handleOptionChange("mat_style", e.target.value)
                      }
                      className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-slate-950 focus:border-slate-950"
                    >
                      <option value="">Select a mat style...</option>
                      {frameSkuData.mat_styles.map((style) => (
                        <option key={style.id} value={style.id}>
                          {style.title}
                        </option>
                      ))}
                    </select>
                  </div>
                )}

              {/* Glass Types */}
              {frameSkuData.glass_types &&
                frameSkuData.glass_types.length > 0 && (
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Glass Type
                    </label>
                    <select
                      value={selectedOptions.glass_type}
                      onChange={(e) =>
                        handleOptionChange("glass_type", e.target.value)
                      }
                      className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-slate-950 focus:border-slate-950"
                    >
                      <option value="">Select a glass type...</option>
                      {frameSkuData.glass_types.map((type) => (
                        <option key={type.id} value={type.id}>
                          {type.title}
                        </option>
                      ))}
                    </select>
                  </div>
                )}

              {/* Paper Types */}
              {frameSkuData.paper_types &&
                frameSkuData.paper_types.length > 0 && (
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Paper Type
                    </label>
                    <select
                      value={selectedOptions.paper_type}
                      onChange={(e) =>
                        handleOptionChange("paper_type", e.target.value)
                      }
                      className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-slate-950 focus:border-slate-950"
                    >
                      <option value="">Select a paper type...</option>
                      {frameSkuData.paper_types.map((type) => (
                        <option key={type.id} value={type.id}>
                          {type.title}
                        </option>
                      ))}
                    </select>
                  </div>
                )}

              {/* Print Sizes */}
              {frameSkuData.frame_sku_sizes &&
                frameSkuData.frame_sku_sizes.length > 0 && (
                  <div>
                    <div className="flex items-center justify-between mb-2">
                      <label className="block text-sm font-medium text-gray-700">
                        Print Size
                      </label>
                      <button
                        type="button"
                        onClick={handleOpenCustomSizeModal}
                        className="text-sm text-gray-600 hover:text-gray-800 underline cursor-pointer"
                      >
                        Define Custom Size
                      </button>
                    </div>
                    <select
                      value={selectedOptions.frame_sku_size}
                      onChange={(e) =>
                        handleOptionChange("frame_sku_size", e.target.value)
                      }
                      className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-slate-950 focus:border-slate-950"
                    >
                      <option value="">All sizes...</option>

                      {/* Custom Sizes */}
                      {customSizes.length > 0 && (
                        <optgroup label="Custom">
                          {customSizes.map((customSize) => (
                            <option
                              key={`custom-${customSize.id}`}
                              value={`custom-${customSize.id}`}
                            >
                              {customSize.full_description}
                            </option>
                          ))}
                        </optgroup>
                      )}

                      {/* Standard Sizes */}
                      <optgroup label="Standard">
                        {frameSkuData.frame_sku_sizes.map((size) => (
                          <option key={size.id} value={size.id}>
                            {size.title}
                          </option>
                        ))}
                      </optgroup>
                    </select>
                  </div>
                )}

            </div>
          </div>
        )}

        {/* Search Results Section */}
        {(searchLoading || searchError || searchResults) && (
          <div className="flex-1 min-h-0 flex flex-col">
            {searchLoading && (
              <div className="flex items-center justify-center py-8">
                <i className="fa-solid fa-spinner-third fa-spin text-blue-600 text-2xl"></i>
                <span className="ml-3 text-gray-600">
                  Searching frame SKUs...
                </span>
              </div>
            )}

            {searchError && (
              <div className="text-center py-8">
                <div className="text-red-600 mb-2">{searchError}</div>
                <button
                  onClick={() => searchFrameSkus(selectedOptions)}
                  className="px-4 py-2 bg-slate-900 text-slate-50 hover:bg-slate-800 rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 cursor-pointer"
                >
                  Try Again
                </button>
              </div>
            )}

            {searchResults && !searchLoading && !searchError && (
              <div className="flex-1 min-h-0 flex flex-col">
                {searchResults.length === 0 ? (
                  <div className="flex items-center justify-center py-16">
                    <div className="text-center max-w-md">
                      {/* Main Message */}
                      <h3 className="text-lg font-medium text-slate-900 mb-2">
                        No frames found
                      </h3>
                      <p className="text-sm text-slate-600 mb-4">
                        No frame products match the selected options. Try
                        adjusting your filters or selecting a different size.
                      </p>

                      {/* Info Box */}
                      <div className="bg-blue-50 rounded-lg p-4 text-left">
                        <p className="text-xs font-medium text-blue-900 mb-1">
                          Frame Size Availability
                        </p>
                        <p className="text-xs text-blue-700">
                          Due to frame strength requirements:{" "}
                          <strong>Skinny</strong> styles available up to A2,{" "}
                          <strong>Slim</strong> styles up to A1, and{" "}
                          <strong>Wide</strong> styles above A1.
                        </p>
                      </div>
                    </div>
                  </div>
                ) : (
                  <div className="flex-1 overflow-auto border border-gray-200 rounded-lg">
                    <table className="min-w-full divide-y divide-gray-200">
                      <thead className="bg-gray-50 sticky top-0 z-10">
                        <tr>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Preview
                          </th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Print Size
                          </th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Frame Style
                          </th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Mat Border
                          </th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Glass Type
                          </th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Paper Type
                          </th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Price
                          </th>
                          <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Action
                          </th>
                        </tr>
                      </thead>
                      <tbody className="bg-white divide-y divide-gray-200">
                        {searchResults.map((sku) => (
                          <tr key={sku.id} className="hover:bg-gray-50">
                            <td className="px-6 py-4 whitespace-nowrap">
                              {sku.preview_image ? (
                                <div className="h-14 w-14">
                                  <img
                                    src={sku.preview_image}
                                    alt={sku.title}
                                    className="object-contain shadow-md"
                                  />
                                </div>
                              ) : (
                                <div className="h-16 w-16 bg-gray-200 rounded-md flex items-center justify-center">
                                  <svg
                                    className="h-8 w-8 text-gray-400"
                                    fill="none"
                                    stroke="currentColor"
                                    viewBox="0 0 24 24"
                                  >
                                    <path
                                      strokeLinecap="round"
                                      strokeLinejoin="round"
                                      strokeWidth="2"
                                      d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                                    />
                                  </svg>
                                </div>
                              )}
                            </td>
                            <td className="px-6 py-4 text-sm text-gray-900">
                              {(() => {
                                // Check if a custom size is selected
                                if (
                                  selectedOptions.frame_sku_size
                                    ?.toString()
                                    .startsWith("custom-")
                                ) {
                                  const customSizeId = parseInt(
                                    selectedOptions.frame_sku_size.replace(
                                      "custom-",
                                      ""
                                    )
                                  );
                                  const customSize = customSizes.find(
                                    (cs) => cs.id === customSizeId
                                  );
                                  if (customSize) {
                                    return (
                                      <span className="text-sm text-gray-900">
                                        {customSize.dimensions_display}
                                        <span className="text-xs text-gray-500">
                                          {" "}
                                          Priced as{" "}
                                          {
                                            customSize.frame_sku_size_description
                                          }
                                        </span>
                                      </span>
                                    );
                                  }
                                }
                                return sku.title || "No size";
                              })()}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              {sku.frame_style || "-"}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              {sku.mat_style || "-"}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              {sku.glass_type || "-"}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              {sku.paper_type || "-"}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                              {formatCentsToPrice(sku.cost_cents)}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                              <div className="flex items-center justify-end gap-2">
                                <button
                                  onClick={() => {
                                    // Get custom size ID if one is selected
                                    let customPrintSizeId = null;
                                    if (
                                      selectedOptions.frame_sku_size
                                        ?.toString()
                                        .startsWith("custom-")
                                    ) {
                                      customPrintSizeId = parseInt(
                                        selectedOptions.frame_sku_size.replace(
                                          "custom-",
                                          ""
                                        )
                                      );
                                    }
                                    toggleSavedItem(sku.id, customPrintSizeId);
                                  }}
                                  className="inline-flex items-center justify-center p-2 text-amber-500 hover:text-amber-600 transition-colors cursor-pointer"
                                  title={
                                    savedFrameSkuIds.includes(sku.id)
                                      ? "Remove from saved"
                                      : "Save for later"
                                  }
                                >
                                  <SvgIcon
                                    name={
                                      savedFrameSkuIds.includes(sku.id)
                                        ? "StarFilledIcon"
                                        : "StarIcon"
                                    }
                                    className="w-5 h-5"
                                  />
                                </button>
                              </div>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {/* Custom Print Size Modal */}
        <CustomPrintSizeModal
          isOpen={customSizeModalOpen}
          onClose={handleCloseCustomSizeModal}
          onSubmit={handleCustomSizeSubmit}
          apiUrl={getApiUrl()}
        />
      </div>
    );
  }

  // Render saved items view
  if (currentStep === "saved-items") {
    return (
      <div className="flex flex-col h-full">
        {/* Breadcrumb Navigation */}
        <div className="mb-4">
          <button
            onClick={handleBackFromSavedItems}
            className="inline-flex items-center text-sm text-gray-600 hover:text-gray-900"
          >
            <SvgIcon name="ChevronLeftIcon" className="w-4 h-4 mr-1" />
            Back to Product Selection
          </button>
          <h2 className="text-2xl font-bold text-gray-900 mt-2">
            {getBreadcrumb()}
          </h2>
        </div>

        {/* Loading State */}
        {savedItemsLoading && (
          <div className="flex items-center justify-center py-8">
            <i className="fa-solid fa-spinner-third fa-spin text-blue-600 text-2xl"></i>
            <span className="ml-3 text-gray-600">Loading saved items...</span>
          </div>
        )}

        {/* Error State */}
        {savedItemsError && (
          <div className="text-center py-8">
            <div className="text-red-600 mb-2">{savedItemsError}</div>
            <button
              onClick={fetchSavedItems}
              className="px-4 py-2 bg-slate-900 text-slate-50 hover:bg-slate-800 rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 cursor-pointer"
            >
              Try Again
            </button>
          </div>
        )}

        {/* Saved Items Content */}
        {!savedItemsLoading && !savedItemsError && (
          <div className="flex-1 min-h-0 flex flex-col">
            {savedItems.length === 0 ? (
              <div className="flex items-center justify-center py-16">
                <div className="text-center max-w-md">
                  <SvgIcon
                    name="StarIcon"
                    className="w-16 h-16 text-gray-300 mx-auto mb-4"
                  />
                  <h3 className="text-lg font-medium text-slate-900 mb-2">
                    No saved items yet
                  </h3>
                  <p className="text-sm text-slate-600 mb-4">
                    Star frame products while browsing to save them here for
                    quick access later.
                  </p>
                </div>
              </div>
            ) : (
              <>
                {/* Filters */}
                {(() => {
                  const printSizes = getUniqueFilterValues(
                    savedItems,
                    "printSize"
                  );
                  // Get unique frame styles with images
                  const frameStyleMap = new Map();
                  savedItems.forEach((item) => {
                    if (
                      item.frame_style &&
                      !frameStyleMap.has(item.frame_style)
                    ) {
                      frameStyleMap.set(item.frame_style, {
                        title: item.frame_style,
                        thumb: item.frame_style_thumb,
                      });
                    }
                  });
                  const frameStyles = Array.from(frameStyleMap.values());

                  const paperTypes = getUniqueFilterValues(
                    savedItems,
                    "paper_type"
                  );
                  const matBorders = getUniqueFilterValues(
                    savedItems,
                    "mat_style"
                  );
                  const glassTypes = getUniqueFilterValues(
                    savedItems,
                    "glass_type"
                  );

                  const hasFilters =
                    printSizes.length > 1 ||
                    frameStyles.length > 1 ||
                    paperTypes.length > 1 ||
                    matBorders.length > 1 ||
                    glassTypes.length > 1;

                  return (
                    hasFilters && (
                      <div className="mb-4 p-4 bg-gray-50 rounded-lg border border-gray-200">
                        <div className="space-y-4">
                          {/* Frame Style Filter */}
                          {frameStyles.length > 1 && (
                            <div>
                              <label className="block text-sm font-medium text-gray-700 mb-2">
                                Frame Style
                              </label>
                              <div className="flex gap-4 overflow-x-auto pb-2">
                                {frameStyles.map((frameStyle) => (
                                  <button
                                    key={frameStyle.title}
                                    type="button"
                                    onClick={() =>
                                      setSavedItemsFilters((prev) => ({
                                        ...prev,
                                        frameStyle: frameStyle.title,
                                      }))
                                    }
                                    className={`flex-shrink-0 flex flex-col items-start relative border-2 rounded-sm overflow-hidden transition-all cursor-pointer ${
                                      savedItemsFilters.frameStyle ===
                                      frameStyle.title
                                        ? "border-slate-900"
                                        : "border-gray-300 hover:border-gray-400"
                                    }`}
                                  >
                                    <div className="w-16 h-16 bg-gray-100 block">
                                      {frameStyle.thumb ? (
                                        <img
                                          src={frameStyle.thumb}
                                          alt={frameStyle.title}
                                          className="w-full h-full object-cover"
                                        />
                                      ) : (
                                        <div className="w-full h-full flex items-center justify-center text-sm text-gray-400">
                                          {frameStyle.title}
                                        </div>
                                      )}
                                    </div>
                                    {savedItemsFilters.frameStyle ===
                                      frameStyle.title && (
                                      <div className="absolute top-1 right-1 bg-slate-900 text-white rounded-full p-1">
                                        <svg
                                          className="w-3 h-3"
                                          fill="currentColor"
                                          viewBox="0 0 20 20"
                                        >
                                          <path
                                            fillRule="evenodd"
                                            d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                                            clipRule="evenodd"
                                          />
                                        </svg>
                                      </div>
                                    )}
                                  </button>
                                ))}
                              </div>
                              {savedItemsFilters.frameStyle && (
                                <div className="mt-2 flex items-center gap-2">
                                  <span className="text-sm text-gray-900 font-medium">
                                    {savedItemsFilters.frameStyle}
                                  </span>
                                  <button
                                    type="button"
                                    onClick={() =>
                                      setSavedItemsFilters((prev) => ({
                                        ...prev,
                                        frameStyle: "",
                                      }))
                                    }
                                    className="text-xs text-gray-600 hover:text-gray-900 underline cursor-pointer"
                                  >
                                    Clear
                                  </button>
                                </div>
                              )}
                            </div>
                          )}

                          {/* Print Size Filter */}
                          {printSizes.length > 1 && (
                            <div>
                              <label className="block text-sm font-medium text-gray-700 mb-2">
                                Print Size
                              </label>
                              <div className="flex flex-wrap gap-2">
                                <button
                                  type="button"
                                  onClick={() =>
                                    setSavedItemsFilters((prev) => ({
                                      ...prev,
                                      printSize: "",
                                    }))
                                  }
                                  className={`px-3 py-1.5 text-sm font-medium rounded-sm transition-colors cursor-pointer ${
                                    !savedItemsFilters.printSize
                                      ? "bg-slate-900 text-white"
                                      : "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
                                  }`}
                                >
                                  All
                                </button>
                                {printSizes.map((size) => (
                                  <button
                                    key={size}
                                    type="button"
                                    onClick={() =>
                                      setSavedItemsFilters((prev) => ({
                                        ...prev,
                                        printSize: size,
                                      }))
                                    }
                                    className={`px-3 py-1.5 text-sm font-medium rounded-sm transition-colors cursor-pointer ${
                                      savedItemsFilters.printSize === size
                                        ? "bg-slate-900 text-white"
                                        : "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
                                    }`}
                                  >
                                    {size}
                                  </button>
                                ))}
                              </div>
                            </div>
                          )}

                          {/* Paper Type Filter */}
                          {paperTypes.length > 1 && (
                            <div>
                              <label className="block text-sm font-medium text-gray-700 mb-2">
                                Paper Type
                              </label>
                              <div className="flex flex-wrap gap-2">
                                <button
                                  type="button"
                                  onClick={() =>
                                    setSavedItemsFilters((prev) => ({
                                      ...prev,
                                      paperType: "",
                                    }))
                                  }
                                  className={`px-3 py-1.5 text-sm font-medium rounded-sm transition-colors cursor-pointer ${
                                    !savedItemsFilters.paperType
                                      ? "bg-slate-900 text-white"
                                      : "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
                                  }`}
                                >
                                  All
                                </button>
                                {paperTypes.map((type) => (
                                  <button
                                    key={type}
                                    type="button"
                                    onClick={() =>
                                      setSavedItemsFilters((prev) => ({
                                        ...prev,
                                        paperType: type,
                                      }))
                                    }
                                    className={`px-3 py-1.5 text-sm font-medium rounded-sm transition-colors cursor-pointer ${
                                      savedItemsFilters.paperType === type
                                        ? "bg-slate-900 text-white"
                                        : "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
                                    }`}
                                  >
                                    {type}
                                  </button>
                                ))}
                              </div>
                            </div>
                          )}

                          {/* Mat Border Filter */}
                          {matBorders.length > 1 && (
                            <div>
                              <label className="block text-sm font-medium text-gray-700 mb-2">
                                Mat Border
                              </label>
                              <div className="flex flex-wrap gap-2">
                                <button
                                  type="button"
                                  onClick={() =>
                                    setSavedItemsFilters((prev) => ({
                                      ...prev,
                                      matBorder: "",
                                    }))
                                  }
                                  className={`px-3 py-1.5 text-sm font-medium rounded-sm transition-colors cursor-pointer ${
                                    !savedItemsFilters.matBorder
                                      ? "bg-slate-900 text-white"
                                      : "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
                                  }`}
                                >
                                  All
                                </button>
                                {matBorders.map((border) => (
                                  <button
                                    key={border}
                                    type="button"
                                    onClick={() =>
                                      setSavedItemsFilters((prev) => ({
                                        ...prev,
                                        matBorder: border,
                                      }))
                                    }
                                    className={`px-3 py-1.5 text-sm font-medium rounded-sm transition-colors cursor-pointer ${
                                      savedItemsFilters.matBorder === border
                                        ? "bg-slate-900 text-white"
                                        : "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
                                    }`}
                                  >
                                    {border}
                                  </button>
                                ))}
                              </div>
                            </div>
                          )}

                          {/* Glass Type Filter */}
                          {glassTypes.length > 1 && (
                            <div>
                              <label className="block text-sm font-medium text-gray-700 mb-2">
                                Glass Type
                              </label>
                              <div className="flex flex-wrap gap-2">
                                <button
                                  type="button"
                                  onClick={() =>
                                    setSavedItemsFilters((prev) => ({
                                      ...prev,
                                      glassType: "",
                                    }))
                                  }
                                  className={`px-3 py-1.5 text-sm font-medium rounded-sm transition-colors cursor-pointer ${
                                    !savedItemsFilters.glassType
                                      ? "bg-slate-900 text-white"
                                      : "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
                                  }`}
                                >
                                  All
                                </button>
                                {glassTypes.map((type) => (
                                  <button
                                    key={type}
                                    type="button"
                                    onClick={() =>
                                      setSavedItemsFilters((prev) => ({
                                        ...prev,
                                        glassType: type,
                                      }))
                                    }
                                    className={`px-3 py-1.5 text-sm font-medium rounded-sm transition-colors cursor-pointer ${
                                      savedItemsFilters.glassType === type
                                        ? "bg-slate-900 text-white"
                                        : "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
                                    }`}
                                  >
                                    {type}
                                  </button>
                                ))}
                              </div>
                            </div>
                          )}
                        </div>
                      </div>
                    )
                  );
                })()}

                <div className="flex-1 overflow-auto border border-gray-200 rounded-lg">
                  <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50 sticky top-0 z-10">
                      <tr>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Preview
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Print Size
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Frame Style
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Mat Border
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Glass Type
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Paper Type
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Price
                        </th>
                        <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Action
                        </th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      {getFilteredSavedItems().map((sku) => (
                        <tr key={sku.id} className="hover:bg-gray-50">
                          <td className="px-6 py-4 whitespace-nowrap">
                            {sku.preview_image ? (
                              <div className="h-14 w-14">
                                <img
                                  src={sku.preview_image}
                                  alt={sku.title}
                                  className="object-contain shadow-md"
                                />
                              </div>
                            ) : (
                              <div className="h-16 w-16 bg-gray-200 rounded-md flex items-center justify-center">
                                <svg
                                  className="h-8 w-8 text-gray-400"
                                  fill="none"
                                  stroke="currentColor"
                                  viewBox="0 0 24 24"
                                >
                                  <path
                                    strokeLinecap="round"
                                    strokeLinejoin="round"
                                    strokeWidth="2"
                                    d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                                  />
                                </svg>
                              </div>
                            )}
                          </td>
                          <td className="px-6 py-4 text-sm text-gray-900">
                            {sku.custom_print_size ? (
                              <span className="text-sm text-gray-900">
                                {sku.custom_print_size.dimensions_display}
                                <span className="text-xs text-gray-500">
                                  {" "}
                                  Priced as{" "}
                                  {
                                    sku.custom_print_size
                                      .frame_sku_size_description
                                  }
                                </span>
                              </span>
                            ) : (
                              sku.title || "No size"
                            )}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {sku.frame_style || "-"}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {sku.mat_style || "-"}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {sku.glass_type || "-"}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {sku.paper_type || "-"}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                            {formatCentsToPrice(sku.cost_cents)}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                            <div className="flex items-center justify-end gap-2">
                              <button
                                onClick={() => toggleSavedItem(sku.id)}
                                className="inline-flex items-center justify-center p-2 text-amber-500 hover:text-amber-600 transition-colors cursor-pointer"
                                title="Remove from saved"
                              >
                                <SvgIcon
                                  name="StarFilledIcon"
                                  className="w-5 h-5"
                                />
                              </button>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </>
            )}
          </div>
        )}
      </div>
    );
  }
}

export default ProductBrowser;
