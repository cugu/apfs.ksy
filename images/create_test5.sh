hdiutil detach disk4
rm test5.dmg

hdiutil create -fs APFS -size 10MB -volname myvolume -quiet test5
hdiutil attach test5.dmg

sleep 1

# volume 1
cd /Volumes/myvolume
mkdir myfolder
seq -sb 13000 | tr -d '[:digit:]' > myfolder/myfile

sleep 4

hdiutil detach disk4

# extract filesystem
# mmls test2.dmg
# dd if=test2.dmg of=test2.dd skip=40 bs=512 count=20400