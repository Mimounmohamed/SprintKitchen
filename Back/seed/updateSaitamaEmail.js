require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');

(async () => {
  await mongoose.connect(process.env.MONGO_URI);
  const u = await User.findOne({ username: 'saitama' });
  if (u) {
    u.email = 'saitama';
    await u.save();
    console.log('SUCCESS: saitama user updated with email = saitama');
  } else {
    console.log('User not found');
  }
  await mongoose.disconnect();
})();
