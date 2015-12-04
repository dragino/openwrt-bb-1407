#!/usr/bin/env bash
# Build all type of image
image_app="IoT fxs yun"

for app in `echo $image_app`;do
	./build_image.sh -a $app
done

echo "Build Done"