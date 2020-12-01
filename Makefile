TARGET = airdrop-secret-extractor
ENTITLEMENTS = entitlements.plist
DEVELOPER_ID = "Apple Development"

sign: $(TARGET) $(ENTITLEMENTS)
	codesign -f -s $(DEVELOPER_ID) --entitlements $(ENTITLEMENTS) $(TARGET)

$(TARGET): main.m
	gcc -framework Foundation -framework Security -iframework /System/Library/PrivateFrameworks/ -framework Sharing -o $(TARGET) main.m

clean:
	rm $(TARGET)

.PHONY: sign clean
