const express = require("express");
const dotenv = require("dotenv").config();
const dbConnect = require("./dbconnect");
const router = require("./routers/router");
const morgan = require("morgan");
const cookieParser = require("cookie-parser");
const cors = require("cors");


const app = express();

//middlewares
app.use(express.json({ limit: "10mb" }));
app.use(morgan("common"));
app.use(cookieParser());

//let origin = 'http://localhost:3000';
//let origin = 'https://wondrous-alfajores-7e4040.netlify.app';

// if(process.env.NODE_ENV === 'production') {
//    origin = process.env.CLIENT_ORIGIN;
    
// }

let origin = 'https://purple-actor-apopb.pwskills.app:3000';
console.log(origin);
app.use(
    cors({
        //credentials: true,
        origin
    })
);


app.use("/catId", router );

app.get("/", (req, res) => {
    res.status(200).send("OK from Catalogue Server");
});

const PORT = process.env.PORT || 4001;

dbConnect();
app.listen(PORT, () => {
    console.log(`listening on port: ${PORT}`);
});