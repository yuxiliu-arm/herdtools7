import fs from "fs";
import { mathjax } from "mathjax-full/js/mathjax";
import { TeX } from "mathjax-full/js/input/tex";
import { CHTML } from "mathjax-full/js/output/chtml";
import { AllPackages } from "mathjax-full/js/input/tex/AllPackages";
import { liteAdaptor } from "mathjax-full/js/adaptors/liteAdaptor";
import { RegisterHTMLHandler } from "mathjax-full/js/handlers/html";
import { MmlNode } from "mathjax-full/js/core/MmlTree/MmlNode";
import { STATE } from "mathjax-full/js/core/MathItem.js";

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

const input = fs.readFileSync(process.argv[3], "utf8");
// console.log("input is: ", input);

console.log(
  toMathML(
    mathjaxDocument.convert(input, {
      display: true, // TODO
      end: STATE.CONVERT,
    }),
  ),
);
