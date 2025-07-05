import { memo } from 'react';
import { Handle, Position } from '@xyflow/react';

const UserNodeComponent = ({ data }) => {
  return (
    <div className="w-[576px] p-6 rounded-lg border-2 border-gray-400 bg-white shadow-lg">
      <Handle 
        type="target" 
        position={Position.Top} 
        id="target"
        className="w-3 h-3 bg-gray-900 !opacity-100" 
      />
      
      <div className="space-y-3">
        <div className="font-semibold text-gray-900 text-lg">You</div>
        <div className="text-gray-800 p-3 bg-gray-50 rounded border break-words">
          {data.prompt}
        </div>
      </div>
      
      <Handle 
        type="source" 
        position={Position.Bottom} 
        id="source"
        className="w-3 h-3 bg-gray-900 !opacity-100" 
      />
    </div>
  );
};

UserNodeComponent.displayName = 'UserNode';

export default memo(UserNodeComponent);
