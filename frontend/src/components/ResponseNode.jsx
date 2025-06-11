import { memo, useState, useEffect } from 'react';
import { Handle, Position } from '@xyflow/react';

const ResponseNodeComponent = ({ data }) => {
  const [inputValue, setInputValue] = useState('');
  const [isLoading, setIsLoading] = useState(data.isLoading || false);

  // Update loading state when data.isLoading changes
  useEffect(() => {
    setIsLoading(data.isLoading || false);
  }, [data.isLoading]);

  const handleSubmit = (e) => {
    e.preventDefault();
    if (data.onPrompt && inputValue.trim()) {
      data.onPrompt(inputValue);
      setInputValue('');
    }
  };

  return (
    <div className="min-w-[300px] p-6 rounded-lg border-2 border-gray-400 bg-white shadow-lg">
      <Handle 
        type="target" 
        position={Position.Top} 
        id="target"
        className="w-3 h-3 bg-gray-900 !opacity-100" 
        isConnectable={true}
        style={{ background: '#64748b' }}
      />
      
      <div className="space-y-4">
        <div className="font-semibold text-gray-900 text-lg">AI Response</div>
        
        <div className="text-gray-800 p-3 bg-gray-50 rounded border min-h-[60px]">
          {isLoading ? (
            <div className="text-gray-500 italic">Generating response...</div>
          ) : (
            data.content || 'No response yet'
          )}
        </div>

        {!isLoading && data.content && data.nodeId && (
          <div className="space-y-3">
            <div className="text-sm text-gray-600">
              Branch count: {data.branchCount || 0}
            </div>
            <form onSubmit={handleSubmit} className="space-y-3">
              <input
                type="text"
                value={inputValue}
                onChange={(e) => setInputValue(e.target.value)}
                placeholder="Continue the conversation..."
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-gray-500 focus:border-gray-500 text-gray-900"
              />
              <button
                type="submit"
                className="w-full px-4 py-2 bg-gray-900 text-white rounded-md hover:bg-gray-800 transition-colors disabled:bg-gray-400"
                disabled={!inputValue.trim()}
              >
                Create Branch
              </button>
            </form>
          </div>
        )}
      </div>
      
      {!isLoading && data.content && (
        <Handle 
          type="source" 
          position={Position.Bottom} 
          id="source"
          className="w-3 h-3 bg-gray-900 !opacity-100" 
          isConnectable={true}
          style={{ background: '#64748b' }}
        />
      )}
    </div>
  );
};

ResponseNodeComponent.displayName = 'ResponseNode';

export default memo(ResponseNodeComponent);
