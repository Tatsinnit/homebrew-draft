#! /bin/bash
TEMP_PATH="./temp"
mkdir -p $TEMP_PATH

gh api graphql --jq '.data.repository.releases.nodes[0].name' -f query='
{
  repository(owner: "azure", name: "draft") {
    releases(first: 1) {
      nodes {
        name
      }
    }
  }
}'  > $TEMP_PATH/release.txt

RELEASE_NAME=$(cat $TEMP_PATH/release.txt | tr -d '"')
echo "RELEASE_NAME: $RELEASE_NAME"

RELEASE_TARBALL_NAME=$(echo "$RELEASE_NAME.tar.gz")
echo "RELEASE_NAME: $RELEASE_TARBALL_NAME"

RELEASE_TARBALL_URL=$(echo "https://github.com/Azure/draft/archive/refs/tags/$RELEASE_TARBALL_NAME")
echo "RELEASE_TARBALL_URL: $RELEASE_TARBALL_URL"

TARBALL_PATH=$(echo "$TEMP_PATH/$RELEASE_TARBALL_NAME")
echo "downloading tarball to $TARBALL_PATH"
curl -sL $RELEASE_TARBALL_URL --output $TARBALL_PATH

SHA=$(sha256sum $TARBALL_PATH | head -c 64)
echo "SHA256: $SHA"

TEMP_FORMULA_PATH=$(echo "$TEMP_PATH/draft.new.rb")

echo """
class Draft < Formula
  desc \"Draft is a tool that creates the miminum required files for your Kubernetes deployments.\"
  homepage \"https://github.com/Azure/draft\"
  version \"$RELEASE_NAME\"
  url \"https://github.com/Azure/draft/archive/refs/tags/$RELEASE_NAME.tar.gz\"
  sha256 \"c6ccdd516fb7a35eb90dfee59c694686240da6ed96c12956e06687eb84384508\"
  license \"MIT\"

  depends_on \"go\" => [:build,\"1.18\"]

  def install
    ENV.deparallelize
    system \"make\", \"all\"
    system \"mkdir\",\"#{prefix}/bin\"
    system \"cp\", \"draft\", \"#{prefix}/bin/draft\"
  end

  test do
    system  \"#{bin}/draft\", \"-v\"
  end
end
""" > $TEMP_FORMULA_PATH

RUBY_CHECK_RESULT=$(ruby -wc $TEMP_FORMULA_PATH)
echo "$RUBY_CHECK_RESULT"

if [ "$RUBY_CHECK_RESULT" = "Syntax OK" ]; then
    echo "VALID RUBY."
    echo "moving $TEMP_FORMULA_PATH to ./Formula/draft.rb"
    mv $TEMP_FORMULA_PATH ./Formula/draft.rb
else
    echo "INVALID RUBY."
    exit 1
fi