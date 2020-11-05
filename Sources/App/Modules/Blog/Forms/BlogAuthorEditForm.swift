//
//  BlogAuthorEditForm.swift
//  FeatherCMS
//
//  Created by Tibor Bodecs on 2020. 03. 23..
//

import FeatherCore

final class BlogAuthorEditForm: Form {

    typealias Model = BlogAuthorModel

    struct Input: Decodable {
        var id: String
        var name: String
        var bio: String
        var image: File?
        var imageDelete: Bool?
    }

    var id: String? = nil
    var name = StringFormField()
    var bio = StringFormField()
    var image = FileFormField()
    var metadata: Metadata?
    var notification: String?
    
    var leafData: LeafData {
        .dictionary([
            "id": id,
            "name": name,
            "bio": bio,
            "image": image,
            "metadata": metadata,
            "notification": notification,
        ])
    }

    init() {}
    
    init(req: Request) throws {
        let context = try req.content.decode(Input.self)
        id = context.id.emptyToNil
        name.value = context.name
        bio.value = context.bio
        image.delete = context.imageDelete ?? false
        if let img = context.image, let data = img.data.getData(at: 0, length: img.data.readableBytes), !data.isEmpty {
            image.data = data
        }
    }
    
    func validate(req: Request) -> EventLoopFuture<Bool> {
        var valid = true

        if let data = image.data, data.isEmpty {
            image.error = "Image is required"
            valid = false
        }
        if name.value.isEmpty {
            name.error = "Name is required"
            valid = false
        }
        return req.eventLoop.future(valid)
    }

    func read(from input: Model)  {
        id = input.id?.uuidString
        name.value = input.name
        image.value = input.imageKey
        bio.value = input.bio
    }

    func write(to output: Model) {
        output.name = name.value
        if !image.value.isEmpty {
            output.imageKey = image.value
        }
        if image.delete {
            output.imageKey = ""
        }
        output.bio = bio.value
    }
}