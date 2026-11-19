import { readFileSync, writeFileSync } from 'node:fs';

const [, , input] = process.argv;
if (!input) throw new Error('Usage: node scripts/generate-crafting-recipes.mjs /path/to/profit/export/recipes.json');

const { build, recipes } = JSON.parse(readFileSync(input, 'utf8'));
const isID = value => Number.isSafeInteger(value) && value > 0;
const bySpell = new Map();
for (const recipe of recipes) {
  const spell = recipe.spell;
  const output = recipe.makes?.item ?? 0;
  const materials = recipe.reagents.flatMap(({ item, count }) => [item, count]);
  const patterns = recipe.recipe_items.map(({ item }) => item);
  if (!isID(spell) || (output !== 0 && !isID(output)) || !materials.length
      || !materials.every(isID) || !patterns.every(isID)) {
    throw new Error(`Invalid recipe data for spell ${spell}`);
  }
  const previous = bySpell.get(spell);
  if (previous) {
    if (previous.output !== output || String(previous.materials) !== String(materials)) {
      throw new Error(`Conflicting recipe data for spell ${spell}`);
    }
    for (const pattern of patterns) previous.patterns.add(pattern);
  } else {
    bySpell.set(spell, { output, materials, patterns: new Set(patterns) });
  }
}

const lines = [
  `-- Generated from Profit's Forever recipe export, client build ${build}.`,
  '-- See THIRD_PARTY_NOTICES.md for source and license.',
  'local _, ns = ...',
  '-- Spell ID, crafted item ID (0 for enchants), recipe items, reagent ID/count pairs.',
  'local rows = {',
];
for (const [spell, { output, materials, patterns }] of [...bySpell].sort(([a], [b]) => a - b)) {
  const patternList = patterns.size ? `{${[...patterns].sort((a, b) => a - b).join(', ')}}` : 'nil';
  lines.push(`    {${spell}, ${output}, ${patternList}, {${materials.join(', ')}}},`);
}
lines.push('}', '', 'local byItem, byRecipe = {}, {}',
  'local function IndexItem(item, recipe)',
  '    local recipes = byItem[item]',
  '    if not recipes then recipes = {}; byItem[item] = recipes end',
  '    if recipes[#recipes] ~= recipe then recipes[#recipes + 1] = recipe end',
  'end',
  'for _, row in ipairs(rows) do',
  '    local recipe, output, patterns, materials = row[1], row[2], row[3], row[4]',
  '    byRecipe[recipe] = materials',
  '    if output > 0 then IndexItem(output, recipe) end',
  '    if patterns then for _, item in ipairs(patterns) do IndexItem(item, recipe) end end',
  'end',
  '-- This enchant scroll uses the same recipe as the spell and formula.',
  'IndexItem(273629, 1248805)',
  'ns.CraftingRecipesByItem, ns.CraftingMaterialsByRecipe = byItem, byRecipe', '');
writeFileSync(new URL('../Data/CraftingRecipes.lua', import.meta.url), lines.join('\n'));
console.log(`Generated ${bySpell.size} recipe records from build ${build}`);
