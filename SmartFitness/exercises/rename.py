import os
import json

# ====================== 配置项 ======================
# 你的主文件夹路径（如果脚本放在目标文件夹里，直接写 '.' 就行）
ROOT_FOLDER = "."
# ====================================================

def rename_images():
    # 获取根目录下所有文件
    for filename in os.listdir(ROOT_FOLDER):
        # 只处理 .json 文件
        if not filename.endswith(".json"):
            continue

        # 提取 json 前缀（不带后缀）
        json_prefix = os.path.splitext(filename)[0]
        json_path = os.path.join(ROOT_FOLDER, filename)
        img_folder = os.path.join(ROOT_FOLDER, json_prefix)  # 对应图片文件夹

        # 如果对应的图片文件夹不存在，跳过
        if not os.path.isdir(img_folder):
            print(f"⚠️  跳过：{json_prefix} 没有对应的图片文件夹")
            continue

        # 要重命名的图片列表
        target_images = ["0.jpg", "1.jpg"]

        for img_name in target_images:
            old_img_path = os.path.join(img_folder, img_name)
            if not os.path.exists(old_img_path):
                continue  # 文件不存在就跳过

            # 新文件名：json前缀_0.jpg 或 json前缀_1.jpg
            new_img_name = f"{json_prefix}_{img_name}"
            new_img_path = os.path.join(img_folder, new_img_name)

            # 执行重命名
            os.rename(old_img_path, new_img_path)
            print(f"✅ 重命名：{old_img_path} → {new_img_path}")

    print("\n🎉 全部处理完成！")

if __name__ == "__main__":
    rename_images()