const router = require("express").Router();
const Controller = require("../controllers/controller");

router.post("/createCatId", Controller.CreateCatalogueId);
router.put("/updateExistingCatId", Controller.updateExistingCatalogueId);
router.post("/getCatId", Controller.getCatalogueId);
router.delete("/deleteCatId", Controller.deleteCatalogueId);
router.get("/getAllCatId", Controller.getAllCatalogues);
router.post('/fileupload', Controller.fileUpload);
router.post('/imageupload', Controller.imageUpload);
router.post('/videoupload', Controller.videoUpload);
router.post('/imagereducer', Controller.imageReducer);

module.exports = router;