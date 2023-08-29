const mongoose = require('mongoose');

const fileSchema = new mongoose.Schema({
    name:{
        type: String,
        required:true
    },
    imageUrl:{
        type:String,
        required:true
    },
    tags:{
        type:String
    },
    email:{
        type:String
    }
})

// fileSchema.post('post', function(doc) {
//     try {
//         console.log(doc);

//         //transporteer
//         let transporter = nodemailer.transporter({
//             host: process.env.MAIL_HOST,
//             auth: {
//                 user: process.env.MAIL_USER,
//                 pass: process.env.MAIL_PASS
//             },

//         })
//     } catch (error) {
//         console.log(error);
//         resizeBy.status(400).json({
//             success: false,
//             message: 'something bad happened while post email middlewear'
//         })
//     }
// })

const File = mongoose.model('File', fileSchema);
module.exports = File;