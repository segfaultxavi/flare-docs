# See README.md for usage instructions.

set -e

YELLOW="\e[93m"
NORMAL="\e[0m"

contracts=""
interfaces=""
internal_interfaces=""
commits=""

while read -r repo_url hardhat_config_file build_command
do
    repo_name=$(basename $repo_url .git)
    echo -e "\n${YELLOW}Clonning $repo_name:${NORMAL}"
    rm -rf $repo_name
    git clone $repo_url --depth 1
    cd $repo_name

    echo -e "\n${YELLOW}Adding docgen to $repo_name:${NORMAL}"
    yarn add solidity-docgen
    sed -i -E "1s/^/import 'solidity-docgen';\n/" $hardhat_config_file
    sed -i -E "/HardhatUserConfig = / r ../hardhat.config.ts.patch" $hardhat_config_file
    cp -r ../template .

    echo -e "\n${YELLOW}Compiling $repo_name:${NORMAL}"
    eval ${build_command}

    echo -e "\n${YELLOW}Building docs for $repo_name:${NORMAL}"
    yarn hardhat docgen

    commits=$(printf "${commits} ${repo_name} $(git rev-parse --short HEAD)")

    cd ..
    while read -r contract_path
    do
        name=$(basename $contract_path)
        path="${repo_name}/docs/api/${contract_path}"
        case $name in
        II[A-Z]*)
            internal_interfaces="${internal_interfaces} ${path}"
            ;;
        I[A-Z]*)
            interfaces="${interfaces} ${path}"
            ;;
        [A-Z]*)
            contracts="${contracts} ${path}"
            ;;
        esac
    done < "${repo_name}.list"

done < "repos.list"

docs=../docs/apis/smart-contracts

# $1 Title
# $2 Subtitle
# $3... List of filenames
print_index () {
    echo >> $docs/index.md
    echo "## $1" >> $docs/index.md
    [[ $2 ]] && echo -e "\n$2" >> $docs/index.md
    shift 2
    echo >> $docs/index.md
    echo "| Name | Description |" >> $docs/index.md
    echo "| ---- | ----------- |" >> $docs/index.md

    rm -f build-docs.tmp
    for f in $@;
    do
        name=$(sed -n '2 s/title: //p' $f)
        # Get the 15th line of the contract md file, where the description lies.
        description=$(sed '15q;d' $f)
        # If the description starts with <, the contract has no description.
        [[ $description = "</div>" ]] && description=""
        echo "| [\`$name\`](./$name.md) | $description |" >> build-docs.tmp
    done
    sort -k2,2 -t'`' build-docs.tmp >> $docs/index.md
    rm build-docs.tmp
}

# $1... List of filenames
print_yml () {
    rm -f build-docs.tmp
    for f in $@;
    do
        echo "      - apis/smart-contracts/$(basename $f)" >> build-docs.tmp
    done
    sort -k1,1 -t. build-docs.tmp >> ../mkdocs.yml.tmp
    rm build-docs.tmp
}

echo -e "\n${YELLOW}Building index pages:${NORMAL}"

# Generate index.md
echo "# Smart Contracts API" > $docs/index.md
echo >> $docs/index.md
echo "<!-- This is an autogenerated file. Do not edit! -->" >> $docs/index.md
echo >> $docs/index.md
echo "List of Flare smart contracts." >> $docs/index.md
print_index "Contracts" "" "$contracts"
print_index "Interfaces" "" "$interfaces"
print_index "Internal Interfaces" "For platform development, not application." "$internal_interfaces"
echo >> $docs/index.md
echo "<style>td:first-child {white-space: nowrap;}</style>" >> $docs/index.md

# Generate mkdocs.yml entries
# Remove all lines below "Smart Contracts API"
sed '/- Smart Contracts API:/,$d' ../mkdocs.yml > ../mkdocs.yml.tmp
# Now list all files
echo "    - Smart Contracts API:" >> ../mkdocs.yml.tmp
echo "      - apis/smart-contracts/index.md" >> ../mkdocs.yml.tmp
print_yml $contracts
print_yml $interfaces
print_yml $internal_interfaces
mv ../mkdocs.yml.tmp ../mkdocs.yml

# Copy all pages to the docs repo
for f in $contracts $interfaces $internal_interfaces;
do
    cp $f $docs
done

# Commit and push changes
# If there are no changes, nothing will be committed nor pushed.
git add ../docs/apis/smart-contracts
git add ../mkdocs.yml
git commit -m "Sync API ref docs with smart contracts" -m "$commits"
#git push

echo -e "\n${YELLOW}Done!${NORMAL}"