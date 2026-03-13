class FfmpegFcvvdp < Formula
  desc "FFmpeg with the fcvvdp perceptual quality filter patch"
  homepage "https://github.com/halidecx/fcvvdp"
  url "https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n8.0.tar.gz"
  sha256 "REPLACE_WITH_FFMPEG_N8_0_TARBALL_SHA256"
  license "GPL-2.0-or-later"

  depends_on "pkgconf" => :build
  depends_on "zig" => :build
  depends_on "nasm" => :build
  depends_on "zlib"
  depends_on "libunwind" unless OS.mac?

  resource "fcvvdp" do
    url "https://github.com/halidecx/fcvvdp/archive/refs/tags/0.2.1.tar.gz"
    sha256 "REPLACE_WITH_FCVVDP_0_2_1_TARBALL_SHA256"
  end

  def install
    resource("fcvvdp").stage do
      # Build the fcvvdp library/header that the FFmpeg patch expects.
      system "zig", "build", "--release=fast"

      # Stage headers and libs into a local prefix the FFmpeg configure step can see.
      (buildpath/"fcvvdp-prefix/include").install Dir["zig-out/include/*"]
      (buildpath/"fcvvdp-prefix/lib").install Dir["zig-out/lib/*"]

      # Apply the upstream FFmpeg integration patch shipped by fcvvdp.
      system "git", "init"
      system "git", "apply", "patches/0001-feat-fcvvdp-support.patch"
    end

    args = %W[
      --prefix=#{prefix}
      --enable-gpl
      --enable-version3
      --enable-fcvvdp
      --enable-zlib
      --cc=#{ENV.cc}
      --cxx=#{ENV.cxx}
      --extra-cflags=-I#{buildpath}/fcvvdp-prefix/include
      --extra-ldflags=-L#{buildpath}/fcvvdp-prefix/lib
    ]

    # On macOS, libunwind is usually provided by the system toolchain.
    # On Linux via Homebrew, you may need the brewed libunwind paths too.
    unless OS.mac?
      args << "--extra-cflags=-I#{Formula["libunwind"].opt_include} -I#{buildpath}/fcvvdp-prefix/include"
      args << "--extra-ldflags=-L#{Formula["libunwind"].opt_lib} -L#{buildpath}/fcvvdp-prefix/lib"
    end

    system "./configure", *args
    system "make", "-j#{ENV.make_jobs}"
    system "make", "install"

    # Optional: install a copy of the built fcvvdp CLI too, since Zig already built it.
    resource("fcvvdp").stage do
      system "zig", "build", "--release=fast"
      bin.install "zig-out/bin/fcvvdp"
    end
  end

  test do
    assert_match "fcvvdp", shell_output("#{bin}/ffmpeg -hide_banner -filters 2>&1")
    assert_match "fcvvdp", shell_output("#{bin}/ffmpeg -hide_banner --help filter=fcvvdp 2>&1")
    assert_match "usage:", shell_output("#{bin}/fcvvdp --help 2>&1")
  end
end