// Create or update an admin account that logs in with a username.
//
// Usage (from the Back folder, with MONGO_URI available):
//   node seed/createAdminUser.js <username> <password> [display name]
//
// Example:
//   node seed/createAdminUser.js saitama "my-password" "Saitama"
require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');

(async () => {
  const [, , rawUsername, password, name] = process.argv;
  const username = (rawUsername || '').trim().toLowerCase();

  if (!username || !password) {
    console.error('Usage: node seed/createAdminUser.js <username> <password> [display name]');
    process.exit(1);
  }
  if (!process.env.MONGO_URI) {
    console.error('MONGO_URI is not set.');
    process.exit(1);
  }

  await mongoose.connect(process.env.MONGO_URI);

  let user = await User.findOne({ username });
  if (user) {
    user.passwordHash = password; // re-hashed by the pre-save hook
    user.role = 'admin';
    user.isActive = true;
    if (name) user.name = name;
    await user.save();
    console.log(`Updated admin "${username}".`);
  } else {
    user = await User.create({
      name: name || username,
      username,
      passwordHash: password,
      role: 'admin',
    });
    console.log(`Created admin "${username}" (id ${user._id}).`);
  }

  await mongoose.disconnect();
  process.exit(0);
})().catch(async (err) => {
  console.error('Failed:', err.message);
  await mongoose.disconnect().catch(() => {});
  process.exit(1);
});
