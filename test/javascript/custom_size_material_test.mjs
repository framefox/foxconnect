import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

const source = await readFile(new URL("../../app/javascript/utils/customSizeMaterial.js", import.meta.url), "utf8");
const { customSizeMaterial } = await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`);

test("framed canvas is canvas before paper options have loaded", () => {
  assert.equal(customSizeMaterial("canvas"), "canvas");
});

test("all paper finishes share the paper size group", () => {
  const types = [{ id: 1, title: "Enhanced Matte" }, { id: 2, title: "Photo Rag" }];
  assert.equal(customSizeMaterial("unmatted", types, "1"), "paper");
  assert.equal(customSizeMaterial("matted", types, "2"), "paper");
});

test("unframed canvas follows the selected paper option", () => {
  const types = [{ id: 1, title: "Paper", material_type: "paper" }, { id: 2, title: "Canvas (Unframed)", material_type: "canvas" }];
  assert.equal(customSizeMaterial("print-only", types, "2"), "canvas");
  assert.equal(customSizeMaterial("print-only", types, "1"), "paper");
});

test("older option responses still recognise unframed canvas", () => {
  assert.equal(customSizeMaterial("print-only", [{ id: 2, title: "Canvas (Unframed)" }], "2"), "canvas");
});
