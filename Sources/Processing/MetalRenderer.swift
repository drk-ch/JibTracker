import Metal
import MetalKit
import AVFoundation

class MetalRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private var textureCache: CVMetalTextureCache?
    private var renderTexture: MTLTexture?
    private var renderPassDescriptor: MTLRenderPassDescriptor?
    
    // Vertex data for rendering
    private let vertices: [Float] = [
        -1.0, -1.0, 0.0, 1.0,  // position, w
        0.0, 0.0,               // texture coordinate
        
        1.0, -1.0, 0.0, 1.0,
        1.0, 0.0,
        
        -1.0, 1.0, 0.0, 1.0,
        0.0, 1.0,
        
        1.0, 1.0, 0.0, 1.0,
        1.0, 1.0
    ]
    
    init?() {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else { return nil }
        self.commandQueue = commandQueue
        
        // Create texture cache
        var textureCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache) != kCVReturnSuccess {
            return nil
        }
        self.textureCache = textureCache
        
        // Create pipeline state
        guard let library = device.makeDefaultLibrary() else { return nil }
        guard let vertexFunction = library.makeFunction(name: "vertexShader"),
              let fragmentFunction = library.makeFunction(name: "fragmentShader") else { return nil }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create pipeline state: \(error)")
            return nil
        }
        
        // Create render pass descriptor
        renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor?.colorAttachments[0].loadAction = .clear
        renderPassDescriptor?.colorAttachments[0].storeAction = .store
        renderPassDescriptor?.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    }
    
    func processFrame(sampleBuffer: CMSampleBuffer, boundingBox: CGRect) -> MTLTexture? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        
        // Create input texture from pixel buffer
        var texture: CVMetalTexture?
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache!,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &texture
        )
        
        guard result == kCVReturnSuccess,
              let texture = texture,
              let inputTexture = CVMetalTextureGetTexture(texture) else {
            return nil
        }
        
        // Create output texture if needed
        if renderTexture == nil || renderTexture?.width != width || renderTexture?.height != height {
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: width,
                height: height,
                mipmapped: false
            )
            textureDescriptor.usage = [.renderTarget, .shaderRead]
            renderTexture = device.makeTexture(descriptor: textureDescriptor)
            
            renderPassDescriptor?.colorAttachments[0].texture = renderTexture
        }
        
        // Render the frame with cropping and lens correction
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = renderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return nil
        }
        
        // Set up vertex buffer
        let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])
        
        // Set up bounding box buffer
        let boundingBoxData: [Float] = [
            Float(boundingBox.origin.x),
            Float(boundingBox.origin.y),
            Float(boundingBox.size.width),
            Float(boundingBox.size.height)
        ]
        let boundingBoxBuffer = device.makeBuffer(bytes: boundingBoxData, length: boundingBoxData.count * MemoryLayout<Float>.size, options: [])
        
        // Set up render state
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(inputTexture, index: 0)
        renderEncoder.setFragmentBuffer(boundingBoxBuffer, offset: 0, index: 0)
        
        // Draw
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        // Commit the command buffer
        commandBuffer.commit()
        
        return renderTexture
    }
} 