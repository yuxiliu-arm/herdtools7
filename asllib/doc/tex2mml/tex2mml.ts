// import fs from "fs";
import { mathjax } from "mathjax-full/js/mathjax";
import { TeX } from "mathjax-full/js/input/tex";
import { CHTML } from "mathjax-full/js/output/chtml";
import { AllPackages } from "mathjax-full/js/input/tex/AllPackages";
import { liteAdaptor } from "mathjax-full/js/adaptors/liteAdaptor";
import { RegisterHTMLHandler } from "mathjax-full/js/handlers/html";
import { STATE } from "mathjax-full/js/core/MathItem.js";
import net from "net";

const adaptor = liteAdaptor();
RegisterHTMLHandler(adaptor);

//
//  Create a MathML serializer
//
import { SerializedMmlVisitor } from "mathjax-full/js/core/MmlTree/SerializedMmlVisitor.js";
const visitor = new SerializedMmlVisitor();
const toMathML = (node: any) => visitor.visitTree(node);

// class MML<N, T, D> extends CHTML<N, T, D> {
//   constructor(...args: any[]) {
//     super(...args);
//     console.log("Creating MML");
//   }

//   /**
//    * @override
//    */
//   public processMath(math: MmlNode, parent: N) {
//     const res = toMathML(math);
//     console.log("here");
//     return res;
//   }
// }

const mml = new CHTML({
  fontURL:
    "https://cdn.jsdelivr.net/npm/mathjax@3/es5/output/chtml/fonts/woff-v2",
});

const mathjaxDocument = mathjax.document("", {
  InputJax: new TeX({ packages: AllPackages, maxBuffer: 10 * 1024 }),
  OutputJax: mml,
});

// const input = fs.readFileSync(process.argv[3], "utf8");
// console.log("input is: ", input);

// console.log(
//   toMathML(
//     mathjaxDocument.convert(input, {
//       display: process.argv[4], // TODO
//       end: STATE.CONVERT,
//     }),
//   ),
// );

const server = net.createServer((c) => {
  // 'connection' listener.
  // console.log("client connected");
  c.on("end", () => {
    // console.log("client disconnected");
  });
  // c.write("hello\r\n");
  c.on("data", (data: any) => {
    const s: string = data.toString();
    const [display, input] = s.startsWith("=====") ? [true, s.slice(5)] : [false, s];
    console.log(s);
    const res = toMathML(
      mathjaxDocument.convert(input, {
        display,
        end: STATE.CONVERT,
      }),
    );
    // console.log(res);
    c.write(res);
  });

  // c.pipe(c);
});

server.on("error", (err) => {
  throw err;
});

server.listen(3000, () => {
  console.log("server bound");
});

// const server = net.createServer((socket) => {
//   socket.on("data", (data: any) => {
//     const s = data.toString();
//     console.log(s);
//     const res = toMathML(
//       mathjaxDocument.convert(s, {
//         display: true, // TODO
//         end: STATE.CONVERT,
//       }),
//     );
//     console.log(res);
//     socket.write("res");
//     socket.end(() => {
//       console.log("closed");
//     });
//   });
// });

// server.listen(3000);
