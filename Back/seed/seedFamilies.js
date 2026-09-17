require('dotenv').config();
const mongoose       = require('mongoose');
const IngredientFamily = require('../models/IngredientFamily');

const FAMILIES = [
  { name: 'Viandes & Protéines',  slug: 'viandes',   emoji: '🥩', displayOrder: 1 },
  { name: 'Féculents & Pains',    slug: 'feculents', emoji: '🍟', displayOrder: 2 },
  { name: 'Sauces & Condiments',  slug: 'sauces',    emoji: '🫙', displayOrder: 3 },
  { name: 'Fromages & Laitiers',  slug: 'fromages',  emoji: '🧀', displayOrder: 4 },
  { name: 'Boissons & Sodas',     slug: 'boissons',  emoji: '🥤', displayOrder: 5 },
  { name: 'Légumes & Garnitures', slug: 'legumes',   emoji: '🥬', displayOrder: 6 },
  { name: 'Épices & Marinades',   slug: 'epices',    emoji: '🧂', displayOrder: 7 },
  { name: 'Autres',               slug: 'autres',    emoji: '📦', displayOrder: 8 },
];

async function seed() {
  const uri = process.env.MONGO_URI;
  if (!uri) { console.error('MONGO_URI not set'); process.exit(1); }

  await mongoose.connect(uri);
  console.log('✅ Connected to MongoDB');

  for (const fam of FAMILIES) {
    const result = await IngredientFamily.findOneAndUpdate(
      { slug: fam.slug },
      { $setOnInsert: fam },
      { upsert: true, new: true }
    );
    console.log(`  • ${result.emoji} ${result.name} (${result.slug})`);
  }

  console.log('\n✅ Seeded ingredient families.');
  await mongoose.disconnect();
  process.exit(0);
}

seed().catch(err => { console.error(err); process.exit(1); });
