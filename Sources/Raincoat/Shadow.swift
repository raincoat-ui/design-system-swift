#if canImport(SwiftUI)
    import RaincoatTokens
    import SwiftUI

    extension View {
        /// Fills `shape` behind this view with `fill`, and draws a token shadow, such as
        /// `tokens.toast.shadow`, with it, as CSS draws a `box-shadow`: the outer layers behind
        /// the fill, the inset layers over the fill and behind the view.
        ///
        /// Every component that lifts a surface draws its shadow token and its fill with this, in
        /// place of a background:
        ///
        ///     let shape = RoundedRectangle(cornerRadius: tokens.card.radius)
        ///     content.raincoatShadow(tokens.card.shadow, in: shape, fill: Color(tokens.card.bg.default))
        ///
        /// It draws only the shadow's visible layers, so a shadow of transparent layers, such as
        /// the base theme's `shadow.none`, draws nothing at all: only the fill. The first layer is
        /// drawn on top, and each is moved by its offset, grown by its spread (shrunk, for an inset
        /// layer), and blurred by half its blur radius, the Gaussian deviation CSS uses. Like any
        /// background, it does not change the size of the view.
        public func raincoatShadow<S: InsettableShape>(
            _ shadow: TokenShadow, in shape: S, fill: Color
        ) -> some View {
            // The first layer is on top, so it is drawn last.
            let layers = Array(shadow.visibleLayers.reversed())
            let outer = layers.filter { !$0.inset }
            let inner = layers.filter(\.inset)
            return background {
                shape.fill(fill)
                    .overlay {
                        ForEach(inner.indices, id: \.self) { index in
                            InsetShadowLayer(layer: inner[index], shape: shape)
                        }
                    }
            }
            .background {
                ForEach(outer.indices, id: \.self) { index in
                    shape
                        .inset(by: -outer[index].spread)
                        .fill(Color(outer[index].color))
                        .offset(x: outer[index].offsetX, y: outer[index].offsetY)
                        .blur(radius: outer[index].blur / 2)
                }
            }
        }
    }

    /// One inset layer: its color inside the shape, except where the shape, moved by the offset
    /// and shrunk by the spread, lets the fill show through.
    private struct InsetShadowLayer<S: InsettableShape>: View {
        let layer: TokenShadowLayer
        let shape: S

        var body: some View {
            Rectangle()
                .fill(Color(layer.color))
                .mask {
                    Rectangle()
                        .overlay {
                            shape
                                .inset(by: layer.spread)
                                .offset(x: layer.offsetX, y: layer.offsetY)
                                .blur(radius: layer.blur / 2)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
                .clipShape(shape)
                .allowsHitTesting(false)
        }
    }
#endif
