const Customer = require('../models/Customer');

// @desc  Search customer by phone (auto-search on livraison form)
// @route GET /api/customers/search?phone=...
exports.searchCustomer = async (req, res) => {
  try {
    const { phone, name } = req.query;
    const filter = {};
    if (phone) filter.phone = { $regex: phone.replace(/\s/g, ''), $options: 'i' };
    if (name) filter.fullName = { $regex: name, $options: 'i' };

    const customers = await Customer.find(filter).limit(10);
    res.json({ success: true, count: customers.length, data: customers });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc  Get single customer
// @route GET /api/customers/:id
exports.getCustomer = async (req, res) => {
  try {
    const customer = await Customer.findById(req.params.id);
    if (!customer) return res.status(404).json({ success: false, message: 'Customer not found' });
    res.json({ success: true, data: customer });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc  Create customer
// @route POST /api/customers
exports.createCustomer = async (req, res) => {
  try {
    const customer = await Customer.create(req.body);
    res.status(201).json({ success: true, data: customer });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// @desc  Update customer
// @route PUT /api/customers/:id
exports.updateCustomer = async (req, res) => {
  try {
    const customer = await Customer.findByIdAndUpdate(req.params.id, req.body, {
      new: true, runValidators: true,
    });
    if (!customer) return res.status(404).json({ success: false, message: 'Customer not found' });
    res.json({ success: true, data: customer });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// @desc  Add address to customer
// @route POST /api/customers/:id/addresses
exports.addAddress = async (req, res) => {
  try {
    const customer = await Customer.findById(req.params.id);
    if (!customer) return res.status(404).json({ success: false, message: 'Customer not found' });
    customer.addresses.push(req.body);
    await customer.save();
    res.status(201).json({ success: true, data: customer.addresses });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};
