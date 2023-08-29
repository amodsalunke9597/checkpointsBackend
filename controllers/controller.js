const { error, success } = require("../utils/responseWrapper");
const User = require("../models/User");
const File = require("../models/File");
const cloud = require('cloudinary').v2;

const Catalogue = require('../models/User');


// this is creating a catId actually
const CreateCatalogueId = async (req, res) => {
    try {
        let { catalogueId, checkpoints } = req.body;

        if (!catalogueId ) {
            return res.send(error(400, 'Catalogue ID is required'));
        }

        if(!checkpoints){
          return res.send(error(400, 'chekpoints are required'));
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

const updateExistingCatalogueId = async (req, res) => {
  try {
      let { catalogueId, checkpoints } = req.body;

      if (!catalogueId) {
          return res.send(error(400, 'Catalogue ID is required'));
      }

      if(!checkpoints){
        return res.send(error(400, 'chekpoints are required'));
      }

      // Check if the provided ID already exists in the database
      let catalogue = await Catalogue.findOne({ catalogueId });

      // If the catalogue exists, update it with the new checkpoints
      if (catalogue) {
          catalogue.checkpoints.push(...checkpoints);
          //catalogue.checkpoints = [...catalogue.checkpoints, ...checkpoints]; // add the new checkpoints to the existing ones
          await catalogue.save();
      } 
      // If the catalogue doesn't exist, return an error
      else {
          return res.send(error(400, 'Catalogue does not exist'));
      }

      return res.json(success(200, { catalogue }));
  } catch (e) {
      console.log(e);
      return res.send(error(500, e.message));
  }
};


const deleteCatalogueId = async (req, res) => {
  try {
    const { catalogueId } = req.body;
    let catalog = await Catalogue.findOne({ catalogueId });
    if (catalog) {
      await catalog.deleteOne();
      res.status(200).json({ msg: 'Catalogue deleted successfully', catalogueId });
    } else {
      res.status(404).json({ msg: 'Catalogue not found', catalogueId });
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ msg: 'Server Error' });
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
};

const getAllCatalogues = async (req, res) => {
  try {
    const catalogues = await Catalogue.find();
    const catalogueData = catalogues.map((catalogue) => {
      return {
        catalogueId: catalogue.catalogueId,
        checkpoints: catalogue.checkpoints
      };
    });
    res.json({catalogueData});
  } catch (err) {
    console.error(`Error getting all catalogues: ${err}`);
    res.status(500).json({ message: err.message });
  }
};

//now from here playing with the files
const fileUpload = async(req, res) => {
  try {
    //fetch files
    const file = req.files.file;
    console.log('this is file', file);
    
    let path = __dirname + '/files/' + Date.now() + `.${file.name.split('.')[1]}`;
    console.log('path => ',path);

    file.mv(path, (err) => {
      console.log(err);
    })

    res.json({
      success:true,
      message:'Local file uploaded successfully'
    })

  } catch (error) {
    console.log(error);
  }
}

function isFileSupported(type, supportedFile){
  return supportedFile.includes(type);
}

async function uploadFileToCloudinary(file, folder, quality){
  const options = {folder};
  options.resource_type = "auto";

  if(quality){
    options.quality = quality;
  }
  return await cloud.uploader.upload(file.tempFilePath, options);
}
//image upload
const imageUpload = async(req, res) => {
  try {
    const {name, tags, email} = req.body;
    console.log(name, tags, email);

    const file = req.files.imagefile;
    console.log(file);

    //validation
    const supportedFile = ["jpg", "jpeg", "png"];
    const fileType = file.name.split('.')[1].toLowerCase();


    // if file format is not supported
    if(!isFileSupported(fileType, supportedFile)){
      return res.status(400).json({
        success: false,
        message: 'file format not supported'
      })
    }

    //file format supported
    const response = await uploadFileToCloudinary(file, "newFolder");
    console.log(response);

    //db me entry save
    const fileData = await File.create({
      name,
      tags,
      email,
      imageUrl: response.secure_url
    })
    res.status(200).json({
      success: true,
      imageUrl: response.secure_url,
      message: 'image saved successfully'
    })


  } catch (error) {
    res.status(400).json({
      success:false,
      message: 'something went wrong'
    })
    console.log(error);
  }
}

//video upload
const videoUpload = async(req, res) => {
  try {
    //fetch used data
    const {name, tags, email} = req.body;

    const file = req.files.videoFile;

     //validation
     const supportedFile = ["mp4", "mov"];
     const fileType = file.name.split('.')[1].toLowerCase();
 
 
     // if file format is not supported
     if(!isFileSupported(fileType, supportedFile)){
       return res.status(400).json({
         success: false,
         message: 'file format not supported'
       })
     }

      //file format supported
    const response = await uploadFileToCloudinary(file, "newFolder");
    console.log(response);

    //db me entry save
    const fileData = await File.create({
      name,
      tags,
      email,
      videoUrl: response.secure_url
    })
    res.status(200).json({
      success: true,
      videoUrl: response.secure_url,
      message: 'image saved successfully'
    })

  } catch (error) {
    console.log(error);
    res.status(400).json({
      success:false,
      message: 'sonmething error happened in videoUpload'
    })
  }
}

//reduce image size
const imageReducer = async(req, res) => {
  try {
    const {name, tags, email} = req.body;
    console.log(name, tags, email);

    const file = req.files.imagefile;
    console.log(file);

    //validation
    const supportedFile = ["jpg", "jpeg", "png"];
    const fileType = file.name.split('.')[1].toLowerCase();


    // if file format is not supported
    if(!isFileSupported(fileType, supportedFile)){
      return res.status(400).json({
        success: false,
        message: 'file format not supported'
      })
    }

    //file format supported
    const response = await uploadFileToCloudinary(file, "newFolder", 80);
    console.log(response);

    //db me entry save
    const fileData = await File.create({
      name,
      tags,
      email,
      imageUrl: response.secure_url
    })
    res.status(200).json({
      success: true,
      imageUrl: response.secure_url,
      message: 'image saved successfully'
    })

  } catch (error) {
    console.log(error);
    res.status(400).json({
      success:false,
      message: 'something went wrong in image reducer'
    })
  }
}
  

module.exports = {
    CreateCatalogueId,
    updateExistingCatalogueId,
    getCatalogueId,
    getAllCatalogues,
    deleteCatalogueId,
    fileUpload,
    imageUpload,
    videoUpload,
    imageReducer
};