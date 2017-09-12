hdiutil detach disk4
rm test4.dmg

hdiutil create -fs APFS -size 10MB -volname myvolume -quiet test4
hdiutil attach test4.dmg

sleep 1

# volume 1
cd /Volumes/myvolume
echo "text.txt" > text.txt
rm text.txt

sleep 4

hdiutil detach -force disk4

# extract filesystem
# mmls test2.dmg
# dd if=test2.dmg of=test2.dd skip=40 bs=512 count=20400