# VariantCard Bundle Implementation Guide

## Overview
This guide shows how to update VariantCard.js to support bundles with multiple slots.

## State Management (Already Added)

```javascript
// Bundle support - check if variant has bundle with multiple slots
const bundle = variant.bundle || null;
const isBundle = bundle && bundle.slot_count > 1;

// For bundles, use bundle.variant_mappings array; for single, use variant.variant_mapping
const [bundleMappings, setBundleMappings] = useState(
  bundle?.variant_mappings || []
);
const [currentSlotPosition, setCurrentSlotPosition] = useState(null);
```

## Helper Functions Needed

### 1. Calculate Combined Frame Cost
```javascript
const calculateTotalFrameCost = () => {
  if (isBundle) {
    return bundleMappings.reduce((total, mapping) => {
      return total + (mapping?.frame_sku_cost_dollars || 0);
    }, 0);
  }
  return variantMapping?.frame_sku_cost_dollars || 0;
};
```

### 2. Get Mapping for Slot
```javascript
const getMappingForSlot = (slotPosition) => {
  return bundleMappings.find(m => m.slot_position === slotPosition) || null;
};
```

### 3. Handle Slot Modal Open
```javascript
const handleSlotClick = (slotPosition) => {
  setCurrentSlotPosition(slotPosition);
  setIsModalOpen(true);
};
```

### 4. Handle Bundle Mapping Update
```javascript
const handleBundleMappingUpdate = (slotPosition, newMapping) => {
  setBundleMappings(prev => {
    const filtered = prev.filter(m => m.slot_position !== slotPosition);
    if (newMapping) {
      return [...filtered, { ...newMapping, slot_position: slotPosition }]
        .sort((a, b) => a.slot_position - b.slot_position);
    }
    return filtered;
  });
};
```

## Rendering Changes

### Slide-down Panel Content

Replace the existing content section with:

```javascript
{isActive && (
  <div className={`${
    (isBundle ? bundleMappings.length > 0 : variantMapping)
      ? "bg-slate-50 border-t border-slate-200"
      : "bg-orange-50 border-t border-orange-100"
  } p-6`}>
    
    {/* Info message if no mappings */}
    {!isBundle && !variantMapping && (
      <p className="text-slate-700 text-sm mb-4">
        Add a product and an image to have Framefox fulfil this item automatically.
      </p>
    )}
    
    {isBundle && bundleMappings.length === 0 && (
      <p className="text-slate-700 text-sm mb-4">
        This is a {bundle.slot_count}-item bundle. Configure each slot with a product and image.
      </p>
    )}
    
    <div className="space-y-3">
      {/* Bundle Slots Grid */}
      {isBundle ? (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {Array.from({ length: bundle.slot_count }, (_, i) => i + 1).map(slotPosition => {
              const mapping = getMappingForSlot(slotPosition);
              
              return (
                <div key={slotPosition} className="bg-white rounded-md p-3 border border-slate-200">
                  {/* Slot Header */}
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs font-semibold text-slate-500">
                      Slot {slotPosition}
                    </span>
                    {mapping && (
                      <button
                        onClick={() => handleSlotClick(slotPosition)}
                        className="text-xs text-slate-600 hover:text-slate-900"
                      >
                        Edit
                      </button>
                    )}
                  </div>
                  
                  {/* Slot Content */}
                  {mapping ? (
                    <RenderSlotMapping mapping={mapping} slotPosition={slotPosition} />
                  ) : (
                    <button
                      onClick={() => handleSlotClick(slotPosition)}
                      className="w-full h-24 flex flex-col items-center justify-center bg-amber-50 border-2 border-dashed border-amber-300 rounded hover:bg-amber-100 transition-all cursor-pointer"
                    >
                      <SvgIcon name="PlusCircleIcon" className="w-5 h-5 text-amber-600 mb-1" />
                      <p className="text-xs text-amber-600 font-medium">Add to Slot {slotPosition}</p>
                    </button>
                  )}
                </div>
              );
            })}
          </div>
          
          {/* Combined Cost Display */}
          {bundleMappings.length > 0 && (
            <div className="bg-white rounded-md p-3 border border-slate-200">
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium text-slate-900">Total Frame Cost:</span>
                <span className="text-sm font-semibold text-slate-900">
                  ${calculateTotalFrameCost().toFixed(2)}
                </span>
              </div>
            </div>
          )}
        </>
      ) : (
        /* Single mapping (existing code) */
        <>
          {variantMapping && <RenderSingleMapping mapping={variantMapping} />}
          {!variantMapping && (
            <button onClick={() => setIsModalOpen(true)}>
              Choose product & image
            </button>
          )}
        </>
      )}
    </div>
  </div>
)}
```

### Helper Render Components

```javascript
const RenderSlotMapping = ({ mapping, slotPosition }) => (
  <div className="flex items-center space-x-2">
    {mapping.framed_preview_thumbnail && (
      <img
        src={mapping.framed_preview_thumbnail}
        alt={`Slot ${slotPosition}`}
        className="w-16 h-16 object-contain rounded"
      />
    )}
    <div className="flex-1 min-w-0">
      <p className="text-xs font-medium text-slate-900 truncate">
        {mapping.frame_sku_title}
      </p>
      <p className="text-xs text-slate-500">
        {mapping.dimensions_display}
      </p>
      <p className="text-xs text-slate-600 font-medium">
        {mapping.frame_sku_cost_formatted}
      </p>
    </div>
  </div>
);
```

## ProductSelectModal Props Update

Update the modal to pass bundle information:

```javascript
<ProductSelectModal
  isOpen={isModalOpen}
  onRequestClose={() => {
    setIsModalOpen(false);
    setCurrentSlotPosition(null);
    setReplaceImageMode(false);
  }}
  productVariantId={variant.id}
  bundleId={bundle?.id}
  slotPosition={currentSlotPosition}
  productTypeImages={productTypeImages}
  replaceImageMode={replaceImageMode}
  existingVariantMapping={
    isBundle 
      ? getMappingForSlot(currentSlotPosition)
      : variantMapping
  }
  onProductSelect={(selection) => {
    if (selection.variantMapping) {
      if (isBundle && currentSlotPosition) {
        handleBundleMappingUpdate(currentSlotPosition, selection.variantMapping);
      } else {
        setVariantMapping(selection.variantMapping);
      }
      
      if (onMappingChange) {
        onMappingChange(variant.id, selection.variantMapping);
      }
    }
    setCurrentSlotPosition(null);
    setReplaceImageMode(false);
  }}
/>
```

## Key Points

1. **Backward Compatible**: Single mappings still work as before
2. **Slot-based UI**: Bundles show a grid of slots
3. **Combined Cost**: Total shown for all bundle slots
4. **Slot Position Tracking**: currentSlotPosition passed to modal
5. **Independent Editing**: Each slot can be edited separately

## Testing Checklist

- [ ] Single-slot bundles display as before
- [ ] Multi-slot bundles show grid layout
- [ ] Each slot can be configured independently
- [ ] Combined cost displays correctly
- [ ] Empty slots show "Add" button
- [ ] Filled slots show preview + edit button
- [ ] Modal correctly updates the right slot

