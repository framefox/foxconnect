import React, { useState, useEffect } from "react";
import CustomPrintSizeModal from "./CustomPrintSizeModal";

function ProductSelectionStep({
  loading,
  error,
  products,
  apiUrl,
  countryCode,
  onCountryChange,
  onProductSelect,
  onRetry,
  onProductTypeChange,
  parentSelectedProductType,
  productTypeImages = {},
}) {
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
  const [selectedCountry, setSelectedCountry] = useState(countryCode || "NZ");
  const [customSizeModalOpen, setCustomSizeModalOpen] = useState(false);
  const [customSizes, setCustomSizes] = useState([]);
  const [customSizesLoading, setCustomSizesLoading] = useState(false);

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
    // Always use selectedCountry to determine URL
    // This allows users to override the order's default country if needed
    const countryUrls = {
      NZ: "http://dev.framefox.co.nz:3001/api",
      AU: "http://dev.framefox.com.au:3001/api",
    };
    return countryUrls[selectedCountry] || countryUrls["NZ"];
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

  // Fetch frame SKU data when product type is selected
  const fetchFrameSkuData = async (productType) => {
    setFrameSkuLoading(true);
    setFrameSkuError(null);

    try {
      const endpoint = productTypes.find(
        (type) => type.id === productType
      )?.endpoint;
      const baseUrl = getApiUrl();
      const response = await fetch(`${baseUrl}/frame_skus/${endpoint}`);

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
    }
  };

  const handleProductTypeSelect = (productType) => {
    setSelectedProductType(productType);
    fetchFrameSkuData(productType);
    fetchCustomSizes(); // Fetch custom sizes when product type is selected
    // Notify parent about product type selection
    if (onProductTypeChange) {
      const productTypeLabel = productTypes.find(
        (type) => type.id === productType
      )?.label;
      onProductTypeChange(productTypeLabel);
    }
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
      const url = `${baseUrl}/frame_skus.json${
        params.toString() ? "?" + params.toString() : ""
      }`;
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

  const handleSearch = () => {
    // If a custom size is selected, use the actual frame_sku_size_id
    if (selectedOptions.frame_sku_size?.toString().startsWith("custom-")) {
      const customSizeId = parseInt(
        selectedOptions.frame_sku_size.replace("custom-", "")
      );
      const customSize = customSizes.find((cs) => cs.id === customSizeId);
      if (customSize) {
        searchFrameSkus({
          ...selectedOptions,
          frame_sku_size: customSize.frame_sku_size_id,
        });
        return;
      }
    }
    searchFrameSkus(selectedOptions);
  };

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
    // Reset product type in parent
    if (onProductTypeChange) {
      onProductTypeChange(null);
    }
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

  // Reset when parent requests it (via breadcrumb click)
  useEffect(() => {
    if (
      parentSelectedProductType === null &&
      currentStep === "option-selection"
    ) {
      // Parent wants to reset, go back to type selection
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
    }
  }, [parentSelectedProductType]);

  // Helper function to format cents to dollars
  const formatCentsToPrice = (cents) => {
    if (!cents && cents !== 0) return "N/A";
    return `$${(cents / 100).toFixed(2)}`;
  };

  // Render product type selection step
  if (currentStep === "type-selection") {
    return (
      <div className="py-8">
        <h3 className="text-lg font-medium text-gray-900 mb-4 text-center">
          Select Product Type
        </h3>

        {/* Country Selector - Compact Button Group */}
        <div className="flex items-center justify-center gap-2 mb-6">
          <span className="text-xs font-medium text-gray-600">Ship to:</span>
          <div className="inline-flex rounded-md shadow-sm" role="group">
            {supportedCountries.map((country, index) => (
              <button
                key={country.code}
                onClick={() => {
                  setSelectedCountry(country.code);
                  if (onCountryChange) {
                    onCountryChange(country.code);
                  }
                }}
                className={`
                  px-3 py-1.5 text-xs font-medium transition-colors
                  ${index === 0 ? "rounded-l-md" : ""}
                  ${
                    index === supportedCountries.length - 1
                      ? "rounded-r-md"
                      : ""
                  }
                  ${
                    selectedCountry === country.code
                      ? "bg-slate-900 text-white"
                      : "bg-white text-gray-700 hover:bg-gray-50 border border-gray-300"
                  }
                  ${
                    index > 0 && selectedCountry !== country.code
                      ? "-ml-px"
                      : ""
                  }
                `}
              >
                {country.code}
              </button>
            ))}
          </div>
        </div>

        <div className="grid grid-cols-2 gap-6 max-w-2xl mx-auto">
          {productTypes.map((type) => (
            <button
              key={type.id}
              onClick={() => handleProductTypeSelect(type.id)}
              className="flex flex-col items-center justify-center p-4 border-2 border-gray-200 rounded-lg hover:border-slate-900 hover:bg-gray-50 transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
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
            </button>
          ))}
        </div>
      </div>
    );
  }

  // Render option selection step
  if (currentStep === "option-selection") {
    return (
      <div className="flex flex-col h-full">
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
              className="px-4 py-2 bg-slate-900 text-slate-50 hover:bg-slate-800 rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
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
                            className={`px-4 py-2 text-sm font-medium rounded-md transition-colors ${
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
                          className={`flex-shrink-0 flex flex-col items-start relative border-1 rounded-lg overflow-hidden transition-all ${
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

                  <div className="mt-4">
                    <label className="block text-sm font-medium text-gray-700">
                      Frame Style:{" "}
                      <span className="text-gray-900">
                        {selectedOptions.frame_style_colour
                          ? frameSkuData.frame_style_colours.find(
                              (c) => c.id === selectedOptions.frame_style_colour
                            )?.title || "Not selected"
                          : "Not selected"}
                      </span>
                    </label>
                  </div>
                </div>
              )}

            {/* Other Options Grid */}
            <div className="grid grid-cols-1 md:grid-cols-5 gap-6">
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
                        className="text-sm text-gray-600 hover:text-gray-800 underline"
                      >
                        Define Custom Size
                      </button>
                    </div>
                    <select
                      value={selectedOptions.frame_sku_size}
                      onChange={(e) => {
                        const value = e.target.value;
                        handleOptionChange("frame_sku_size", value);

                        // If it's a custom size, we need to trigger search with the actual frame_sku_size_id
                        if (value.startsWith("custom-")) {
                          const customSizeId = parseInt(
                            value.replace("custom-", "")
                          );
                          const customSize = customSizes.find(
                            (cs) => cs.id === customSizeId
                          );
                          if (customSize) {
                            searchFrameSkus({
                              ...selectedOptions,
                              frame_sku_size: customSize.frame_sku_size_id,
                            });
                          }
                        }
                      }}
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

              {/* Search Button */}
              <div className="flex flex-col justify-end">
                <button
                  onClick={handleSearch}
                  disabled={searchLoading}
                  className="w-full px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  {searchLoading ? (
                    <>
                      <i className="fa-solid fa-spinner-third fa-spin mr-2"></i>
                      Searching...
                    </>
                  ) : (
                    <>
                      <svg
                        className="w-4 h-4 mr-2 inline"
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
                      Search
                    </>
                  )}
                </button>
              </div>
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
                  className="px-4 py-2 bg-slate-900 text-slate-50 hover:bg-slate-800 rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
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
                              <button
                                onClick={() => {
                                  // Check if a custom size is selected
                                  let customSizeData = null;
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
                                      customSizeData = {
                                        user_width: customSize.long, // Use long for width (will be normalized in parent)
                                        user_height: customSize.short, // Use short for height
                                        user_unit: customSize.unit,
                                      };
                                    }
                                  }
                                  onProductSelect(sku, customSizeData);
                                }}
                                className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-slate-50 bg-slate-900 hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-950 transition-colors"
                              >
                                Select
                              </button>
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
}

export default ProductSelectionStep;
