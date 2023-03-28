const mongoose = require("mongoose");

const catalogueSchema = mongoose.Schema({
    catalogueId: {
        type: String,
        required: true,
        unique: true,
        lowercase: true,
    },
    checkpoints: [
        {
            type: String,
            //type: mongoose.Schema.Types.ObjectId,
            ref: 'catalogue'
        }
    ]
}, {
    timestamps: true
});

module.exports = mongoose.model("catalogue", catalogueSchema);
