const router = require("express").Router();
const Controller = require("../controllers/controller");

router.post("/createCatId", Controller.createCatalogueId);
router.post("/updateCatId", Controller.updateCatalogueId);
router.put("/updateExistingCatId", Controller.updateExistingCatalogueId);
router.post("/getCatId", Controller.getCatalogueId);
router.delete("/deleteCatId", Controller.deleteCatalogueId);
router.get("/getAllCatId", Controller.getAllCatalogues);

module.exports = router;