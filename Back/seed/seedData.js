/**
 * SprintKitchen — Seed Data
 * Run with: node seed/seedData.js
 *
 * Populates: Store, Registers, Categories, Products (with customization groups), Admin User
 */
require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const mongoose = require('mongoose');

const Store     = require('../models/Store');
const Register  = require('../models/Register');
const Category  = require('../models/Category');
const Product   = require('../models/Product');
const User      = require('../models/User');

// ─── Helpers ──────────────────────────────────────────────────────────────────
const burgerCustomizations = [
  {
    stepNumber: 1,
    name: 'Cuisson de la viande',
    type: 'single',
    isRequired: true,
    minChoices: 1,
    maxChoices: 1,
    options: [
      { label: 'Saignant',  priceModifier: 0, isDefault: false },
      { label: 'À point',   priceModifier: 0, isDefault: true  },
      { label: 'Bien cuit', priceModifier: 0, isDefault: false },
    ],
  },
  {
    stepNumber: 2,
    name: 'Choix de la sauce',
    type: 'multi',
    isRequired: false,
    minChoices: 0,
    maxChoices: 3,
    options: [
      { label: 'Algérienne', priceModifier: 0, isDefault: false },
      { label: 'Burger',     priceModifier: 0, isDefault: true  },
      { label: 'Mayonnaise', priceModifier: 0, isDefault: false },
      { label: 'Ketchup',    priceModifier: 0, isDefault: false },
      { label: 'Samourai',   priceModifier: 0, isDefault: false },
      { label: 'Barbecue',   priceModifier: 0, isDefault: false },
    ],
  },
  {
    stepNumber: 3,
    name: 'Accompagnement',
    type: 'single',
    isRequired: false,
    minChoices: 0,
    maxChoices: 1,
    options: [
      { label: 'Cheddar Bacon',  priceModifier: 0,    isDefault: false },
      { label: 'Frites Maison',  priceModifier: 0,    isDefault: true  },
      { label: 'Salade Verte',   priceModifier: 0,    isDefault: false },
      { label: 'Onion Rings',    priceModifier: 1.20, isDefault: false },
    ],
  },
  {
    stepNumber: 5,
    name: 'Suppléments & Extras',
    type: 'multi',
    isRequired: false,
    minChoices: 0,
    maxChoices: 10,
    options: [
      { label: 'Double Cheese',       priceModifier: 1.50, isDefault: false },
      { label: 'Bacon croustillant',  priceModifier: 1.20, isDefault: false },
      { label: 'Oignons frits',       priceModifier: 0.80, isDefault: false },
      { label: 'Jalapeños',           priceModifier: 0.50, isDefault: false },
    ],
  },
  {
    stepNumber: 6,
    name: 'Ingrédients à retirer',
    type: 'multi',
    isRequired: false,
    minChoices: 0,
    maxChoices: 10,
    options: [
      { label: 'Sans Oignon',    priceModifier: 0, isDefault: false },
      { label: 'Sans Tomate',    priceModifier: 0, isDefault: false },
      { label: 'Sans Salade',    priceModifier: 0, isDefault: false },
      { label: 'Sans Cornichon', priceModifier: 0, isDefault: false },
    ],
  },
];

const simpleCustomizations = [
  {
    stepNumber: 2,
    name: 'Choix de la sauce',
    type: 'multi',
    isRequired: false,
    minChoices: 0,
    maxChoices: 2,
    options: [
      { label: 'Algérienne', priceModifier: 0, isDefault: false },
      { label: 'Burger',     priceModifier: 0, isDefault: true  },
      { label: 'Mayonnaise', priceModifier: 0, isDefault: false },
      { label: 'Ketchup',    priceModifier: 0, isDefault: false },
    ],
  },
];

// ─── Main seed function ───────────────────────────────────────────────────────
async function seedDB() {
  await mongoose.connect(process.env.MONGO_URI);
  console.log('✅ Connected to MongoDB');

  // Clear existing data
  await Promise.all([
    Store.deleteMany({}),
    Register.deleteMany({}),
    Category.deleteMany({}),
    Product.deleteMany({}),
    User.deleteMany({}),
  ]);
  console.log('🗑  Cleared existing collections');

  // ── Store ──────────────────────────────────────────────────────────────────
  const store = await Store.create({
    name: 'SprintKitchen Paris République',
    storeNumber: '04',
    address: {
      street: '14 Rue de la République',
      city: 'Paris',
      postalCode: '75011',
      country: 'France',
    },
    phone: '+33 1 00 00 00 00',
    tvaRate: 10,
    services: [
      { name: 'Déjeuner', startTime: '11:00', endTime: '15:00', isActive: true },
      { name: 'Dîner',    startTime: '18:00', endTime: '23:00', isActive: true },
    ],
  });
  console.log(`🏪 Store created: ${store.name}`);

  // ── Admin User ─────────────────────────────────────────────────────────────
  const admin = await User.create({
    name: 'Admin',
    email: 'admin@sprintkitchen.fr',
    passwordHash: 'Admin1234!',
    role: 'admin',
    storeId: store._id,
    pin: '0000',
  });
  console.log(`👤 Admin user: ${admin.email} / Admin1234!`);

  // ── Registers ──────────────────────────────────────────────────────────────
  const registers = await Register.insertMany([
    { name: 'Caisse 01', type: 'caisse',   storeId: store._id, hardware: { printerModel: 'Epson TM-T88', drawerConnected: true } },
    { name: 'Caisse 02', type: 'caisse',   storeId: store._id },
    { name: 'Borne 01',  type: 'borne',    storeId: store._id },
    { name: 'Borne 02',  type: 'borne',    storeId: store._id },
  ]);
  console.log(`🖥  ${registers.length} registers created`);

  // ── Categories ─────────────────────────────────────────────────────────────
  const cats = await Category.insertMany([
    { name: 'Menus B',              slug: 'menus-b',           displayOrder: 1, storeId: store._id },
    { name: 'Menus L',              slug: 'menus-l',           displayOrder: 2, storeId: store._id },
    { name: 'Menu Simple',          slug: 'menu-simple',       displayOrder: 3, storeId: store._id },
    { name: 'Nos Starters',         slug: 'nos-starters',      displayOrder: 4, storeId: store._id },
    { name: 'Nos Burgers',          slug: 'nos-burgers',       displayOrder: 5, storeId: store._id },
    { name: 'Nos Sandwichs',        slug: 'nos-sandwichs',     displayOrder: 6, storeId: store._id },
    { name: 'Menu Enfant',          slug: 'menu-enfant',       displayOrder: 7, storeId: store._id },
    { name: 'Nos Desserts',         slug: 'nos-desserts',      displayOrder: 8, storeId: store._id },
    { name: 'Boissons & Cafés',     slug: 'boissons-cafes',    displayOrder: 9, storeId: store._id },
    { name: 'Accompagnements',      slug: 'accompagnements',   displayOrder: 10, storeId: store._id },
    { name: 'Sauces & Extras',      slug: 'sauces-extras',     displayOrder: 11, storeId: store._id },
  ]);
  const catMap = Object.fromEntries(cats.map(c => [c.slug, c._id]));
  console.log(`📂 ${cats.length} categories created`);

  // ── Products — Menus B ─────────────────────────────────────────────────────
  const menusBProducts = [
    { name: 'Menu B1', description: 'Steak haché pur bœuf, Cheddar affiné, Pickles, Oignons frais, Sauce maison',                                                          basePrice: 8.00,  displayOrder: 1,  availability: 'available' },
    { name: 'Menu B2', description: 'Double smash, Bacon fumé croustillant, Cheddar rouge, Sauce BBQ fumée',                                                                basePrice: 9.00,  displayOrder: 2,  availability: 'epuise',   isOnList86: true, blockedOnCaisse: true, blockedOnBorne: true },
    { name: 'Menu B3', description: 'Triple steak, Cheddar affiné, Oignons caramélisés, Sauce secrète',                                                                    basePrice: 9.00,  displayOrder: 3,  availability: 'available' },
    { name: 'Menu B4', description: 'Menu B4 Cheese',                                                                                                                      basePrice: 10.00, displayOrder: 4,  availability: 'available' },
    { name: 'Menu B5', description: 'Smash Burger Original — Petites smertes pressées, Double American cheese, Sauce smash signature',                                     basePrice: 9.00,  displayOrder: 5,  availability: 'available' },
    { name: 'Menu B6', description: 'Double smash, Jalapeños marinés, Pepper Jack cheese, Sauce fiery chipotle',                                                            basePrice: 10.00, displayOrder: 6,  availability: 'available' },
    { name: 'Menu B7', description: 'Burger maison',                                                                                                                        basePrice: 10.00, displayOrder: 7,  availability: 'available' },
    { name: 'Menu B8', description: 'Double Smash Spicy',                                                                                                                  basePrice: 11.00, displayOrder: 8,  availability: 'available' },
    { name: 'Menu B9', description: 'Veggie Truffle Smash — Deux végétal champignons à lentilles, Sauce émulsion truffes, Roquette fraîche',                               basePrice: 10.00, displayOrder: 9,  availability: 'available' },
    { name: 'Menu B10', description: 'Menu B10',                                                                                                                            basePrice: 11.00, displayOrder: 10, availability: 'available' },
    { name: 'Menu B11', description: 'Menu B11',                                                                                                                            basePrice: 11.00, displayOrder: 11, availability: 'available' },
    { name: 'Menu B12', description: 'Bacon Monster 86 — Triple bacon grillé, Oignons caramélisés, Sauce secrète',                                                         basePrice: 11.00, displayOrder: 12, availability: 'bloque_caisse_borne', isOnList86: true, blockedOnCaisse: true, blockedOnBorne: true },
    { name: 'Menu B13', description: 'Menu B13',                                                                                                                            basePrice: 10.00, displayOrder: 13, availability: 'available' },
    { name: 'Menu Bacon', description: 'Menu Bacon',                                                                                                                        basePrice: 10.00, displayOrder: 14, availability: 'available' },
    { name: 'Menu Crispy', description: 'Filet de poulet pané maïs croustillants, Salade iceberg, Sauce creamy mayo',                                                      basePrice: 11.50, displayOrder: 15, availability: 'available' },
    // B4 Cheese with full personnalisation
    { name: 'Menu B4 Cheese', description: 'Sauce Algérienne, Cuisson à point',                                                                                            basePrice: 10.00, displayOrder: 4,  availability: 'available', customizationGroups: burgerCustomizations },
  ].map(p => ({ ...p, categoryId: catMap['menus-b'], storeId: store._id, kdsStation: 'grill', customizationGroups: p.customizationGroups || burgerCustomizations }));

  // ── Products — Accompagnements ─────────────────────────────────────────────
  const accompProducts = [
    { name: 'Frites Maison',    description: 'Frites maison fraîches',              basePrice: 3.50,  kdsStation: 'frites' },
    { name: 'Frites Maison XL', description: 'Sans sel ajouté',                     basePrice: 4.00,  kdsStation: 'frites' },
    { name: 'Onion Rings',      description: 'Rondelles d\'oignons panées',          basePrice: 3.50,  kdsStation: 'frites' },
    { name: 'Salade Verte',     description: 'Salade verte fraîche',                 basePrice: 2.50,  kdsStation: 'general' },
    { name: 'Cheddar Bacon',    description: 'Cheddar fondu et bacon croustillant',  basePrice: 2.50,  kdsStation: 'general' },
  ].map(p => ({ ...p, categoryId: catMap['accompagnements'], storeId: store._id, customizationGroups: [] }));

  // ── Products — Boissons ────────────────────────────────────────────────────
  const boissonsProducts = [
    { name: 'Coca-Cola 33cl',          description: 'Coca-Cola 33cl',           basePrice: 2.50,  kdsStation: 'boissons' },
    { name: 'Coca-Cola Sans Sucres 33cl', description: 'Sans sucres ajoutés',   basePrice: 2.50,  kdsStation: 'boissons' },
    { name: 'Fanta Orange 33cl',       description: 'Fanta Orange 33cl',        basePrice: 2.50,  kdsStation: 'boissons' },
    { name: 'Eau Plate 50cl',          description: 'Eau minérale plate',        basePrice: 1.50,  kdsStation: 'boissons' },
    { name: 'Espresso Pur Arabica',    description: 'Café expresso',             basePrice: 1.50,  kdsStation: 'boissons' },
    { name: 'Latte Macchiato',         description: 'Latte macchiato',           basePrice: 2.50,  kdsStation: 'boissons' },
  ].map(p => ({ ...p, categoryId: catMap['boissons-cafes'], storeId: store._id, customizationGroups: [] }));

  const allProducts = [...menusBProducts, ...accompProducts, ...boissonsProducts];
  const products = await Product.insertMany(allProducts);
  console.log(`🍔 ${products.length} products created`);

  console.log('\n✅ ========================');
  console.log('   Seed completed!');
  console.log('   API: http://localhost:5000/api/health');
  console.log('   Login: admin@sprintkitchen.fr / Admin1234!');
  console.log('========================\n');

  await mongoose.disconnect();
  process.exit(0);
}

seedDB().catch(err => {
  console.error('❌ Seed failed:', err);
  mongoose.disconnect();
  process.exit(1);
});
