
# Checksum
According to the [apple docs](https://developer.apple.com/library/content/documentation/FileManagement/Conceptual/APFS_Guide/FAQ/FAQ.html) the Fletcher's checksum algorithm is used. Apple uses a variant of the algorithm described in a [paper by John Kodis](http://collaboration.cmc.ec.gc.ca/science/rpn/biblio/ddj/Website/articles/DDJ/1992/9205/9205b/9205b.htm). The following algorithm shows this procedure. The input is the block without the first 8 byte.

```go
func createChecksum(data []byte) uint64 {
    var sum1, sum2 uint64

    modValue := uint64(2<<31 - 1)

    for i := 0; i < len(data)/4; i++ {
        d := binary.LittleEndian.Uint32(data[i*4 : (i+1)*4])
        sum1 = (sum1 + uint64(d)) % modValue
        sum2 = (sum2 + sum1) % modValue
    }

    check1 := modValue - ((sum1 + sum2) % modValue)
    check2 := modValue - ((sum1 + check1) % modValue)

    return (check2 << 32) | check1
}
```

The nice feature of the algorithm is, that when you check a block in APFS with the following algorithm you should get null as a result. Note that the input in this case is the whole block, including the checksum.

```go
func checkChecksum(data []byte) uint64 {
    var sum1, sum2 uint64

    modValue := uint64(2<<31 - 1)

    for i := 0; i < len(data)/4; i++ {
        d := binary.LittleEndian.Uint32(data[i*4 : (i+1)*4])
        sum1 = (sum1 + uint64(d)) % modValue
        sum2 = (sum2 + sum1) % modValue
    }

    return (sum2 << 32) | sum1
}
```
