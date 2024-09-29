//
//  OpenGalleryView.swift
//  SwiftUIDemo
//
//  Created by 吴伟 on 9/29/24.
//

import SwiftUI

// 主视图
struct OpenGalleryView: View {
    @State private var pickedImage: UIImage?
    @State private var backgroundImage: UIImage?
    @State private var finalImage: UIImage?
    @State private var showingImagePicker = false

    var body: some View {
        VStack(spacing: 20) {
            Button("Select Image") {
                showingImagePicker = true
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(pickedImage: $pickedImage)
            }

            if let image = pickedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
            }
            
            Button("Remove Background") {
                if let image = pickedImage {
                    finalImage = image.removeBackground(returnResult: .finalImage)
                }
            }
            
            if let image = backgroundImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
            }
            
            if let image = finalImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
            }
        }
        .padding()
    }
}

#Preview {
    OpenGalleryView()
}
