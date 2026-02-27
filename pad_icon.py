from PIL import Image, ImageOps

img = Image.open('assets/icon/app_icon.jpeg')
w, h = img.size
# Add an 8% border
pad_w = int(w * 0.08)
pad_h = int(h * 0.08)
new_img = ImageOps.expand(img, border=(pad_w, pad_h), fill='white')
new_img.save('assets/icon/app_icon_padded.jpeg')
print("Image padded successfully!")
