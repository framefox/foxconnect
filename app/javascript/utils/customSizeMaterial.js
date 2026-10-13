// Canvas can also be offered as an unframed print.
export function customSizeMaterial(productType, paperTypes = [], paperTypeId) {
  if (productType === "canvas") return "canvas";
  const paperType = paperTypes?.find((type) => String(type.id) === String(paperTypeId));
  return paperType?.material_type || (/canvas/i.test(paperType?.title || "") ? "canvas" : "paper");
}
