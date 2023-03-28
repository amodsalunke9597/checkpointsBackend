const router = require("express").Router();
const Controller = require("../controllers/controller");

router.post("/createCatId", Controller.createCatalogueId);
router.post("/updateCatId", Controller.updateCatalogueId);
router.post("/getCatId", Controller.getCatalogueId);

module.exports = router;