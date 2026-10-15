import React from "react";

export default function MissingFramePreview({ mapping, onEdit, compact = false }) {
  return (
    <div className={`${compact ? "w-20" : "w-36"} flex-shrink-0 text-center space-y-1 rounded bg-slate-50 p-2`}>
      {mapping.artwork_preview_thumbnail && (
        <img src={mapping.artwork_preview_thumbnail} alt="Attached artwork" className="w-full h-16 object-contain" />
      )}
      <p className="text-xs font-medium text-slate-700">Image attached</p>
      <p className="text-xs text-slate-500">Frame preview unavailable</p>
      {onEdit && <button type="button" onClick={onEdit} className="text-xs underline text-slate-700">Edit image</button>}
    </div>
  );
}
