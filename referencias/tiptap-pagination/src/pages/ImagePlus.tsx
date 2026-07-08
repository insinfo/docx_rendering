import { OpenForWork } from "@/ui/open-for-work";
import TiptapEditor from "@/components/image-plus/tiptap-editor";
import { useSearchParams } from "react-router-dom";
import { useMemo } from "react";

function ImagePlus() {
  const [searchParams] = useSearchParams();
  const onlyEditor = useMemo(() => searchParams.has("frame"), [searchParams]);
  return (
    <div className="max-w-4xl mx-auto px-2 relative">
      <TiptapEditor onlyEditor={onlyEditor} />
      {onlyEditor ? <> </> : <OpenForWork />} 
    </div>
  );
}

export default ImagePlus;
