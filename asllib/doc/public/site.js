function issueSearch() {
  const searchBox = document.getElementById("searchBox");
  if (searchBox) {
    const query = searchBox.value;
    const url = new URL(
      "http://acyclic.cambridge.arm.com/test-search-the-architecture",
    );
    const searchParams = url.searchParams;
    searchParams.set("q", encodeURIComponent(query));
    searchParams.set("f", encodeURIComponent("as"));
    url.search = searchParams.toString();
    window.open(url.href, "_blank");
  }
}

onload = () => {
  const currentTitle = document.querySelector("h1");
  const id = currentTitle ? currentTitle.id : null;
  // https://github.com/jgm/pandoc-website/blob/8c5fee08486cd5e6511579766313848f06ac3f2c/js/site.js#L2-L23
  document.querySelectorAll("#TOC > ul > li").forEach(function (li) {
    if (li.children.length > 1) {
      const toggle = document.createElement("span");
      toggle.className = "toggle";
      toggle.innerHTML = "▸";
      toggle.onclick = function () {
        const sublist = li.getElementsByTagName("ul")[0];
        if (sublist) {
          if (sublist.style.display === "none") {
            sublist.style.display = "block";
            toggle.innerHTML = "▾";
          } else {
            sublist.style.display = "none";
            toggle.innerHTML = "▸";
          }
        }
      };
      li.prepend(toggle);
      if (id) {
        // expand current chapter's toc
        const anchor = li.getElementsByTagName("a")[0];
        const href = anchor ? anchor.href.split("#").pop() : undefined;
        if (href && href === id) {
          return;
        }
      }
      toggle.click();
    }
  });

  const searchBox = document.getElementById("searchBox");
  searchBox.onkeydown = (event) => {
    if (event.key == "Enter") {
      issueSearch();
    }
  };
  updateSearchBoxParent();
};

window.onresize = () => {
  updateSearchBoxParent();
};

// if width > 768px, #TOC is shown, move to #TOC
// otherwise, #sitenav is used, move to #sitenav
function updateSearchBoxParent() {
  const s = document.getElementById("searchBox");
  if (s && window.innerWidth <= 768) {
    const sitenav = document.getElementById("sitenav");
    if (sitenav) {
      sitenav.prepend(s);
    }
  } else {
    const toc = document.getElementById("TOC");
    if (toc) {
      toc.prepend(s);
    }
  }
}
