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
  const nav = document.getElementById("sitenav");
  if (nav) {
    const searchDiv = document.createElement("div");
    searchDiv.id = "searchDiv";

    const searchBox = document.createElement("input");
    searchBox.type = "text";
    searchBox.id = "searchBox";
    searchBox.placeholder = "Search...";
    searchBox.onkeydown = (event) => {
      if (event.key == "Enter") {
        issueSearch();
      }
    };
    searchDiv.appendChild(searchBox);

    const searchButton = document.createElement("button");
    searchButton.id = "searchButton";
    searchButton.onclick = issueSearch();
    searchButton.textContent = "Search";
    searchDiv.appendChild(searchButton);

    nav.before(searchDiv);
  }
};
