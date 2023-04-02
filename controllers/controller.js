const { error, success } = require("../utils/responseWrapper");
const User = require("../models/User");

const Catalogue = require('../models/User');

// Create a new catalog ID and add checkpoints
const createCatalogueId = async (req, res) => {
    try {
      const { catalogueId } = req.body;
      let catalog = await Catalogue.findOne({ catalogueId });
      if (catalog) {
        return res.status(400).json({ msg: 'Catalogue already exists' });
      }
  
      catalog = new Catalogue({ catalogueId });
      await catalog.save();
  
      res.status(200).json({ msg: 'Catalogue created successfully', catalog });
    } catch (err) {
      console.error(err);
      res.status(500).send('Server Error');
    }
  
};


const updateCatalogueId = async (req, res) => {
    try {
        let { catalogueId, checkpoints } = req.body;

        if (!catalogueId) {
            return res.send(error(400, 'Catalogue ID is required'));
        }

        // Check if the provided ID already exists in the database
        let catalogue = await Catalogue.findOne({ catalogueId });

        // If the catalogue exists, update it with the new checkpoints
        if (catalogue) {
            catalogue.checkpoints = checkpoints;
            await catalogue.save();
        } 
        // If the catalogue doesn't exist, create it
        else {
            catalogue = await Catalogue.create({ catalogueId, checkpoints });
        }

        return res.json(success(200, { catalogue }));
    } catch (e) {
      console.log(e);
        return res.send(error(500, e.message));
    }
};


  

// Get a catalog ID by catalogue ID
const getCatalogueId = async (req, res, next) => {
  try {
    const { catalogueId } = req.body;
    const catalogue = await Catalogue.findOne({ catalogueId });
    if (!catalogue) {
        throw new Error(`Catalogue with ID ${catalogueId} not found`);
    }

    const checkpoints = catalogue.checkpoints

    res.json({checkpoints});
} catch (err) {
    console.error(`Error getting catalogue checkpoints: ${err}`);
    res.status(404).json({ message: err.message });
}
}


  

module.exports = {
    createCatalogueId,
    updateCatalogueId,
    getCatalogueId,
};