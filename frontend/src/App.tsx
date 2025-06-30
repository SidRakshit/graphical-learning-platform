import { useState, useCallback, useEffect } from 'react';
import { ReactFlowProvider, ReactFlow } from '@xyflow/react';
import {
  Controls,
  Background,
  useNodesState,
  useEdgesState,
  MarkerType,
  Panel,
  type Node,
  type Edge,
} from '@xyflow/react';
import '@xyflow/react/dist/style.css';
import InitialNode from './components/InitialNode';
import UserNode from './components/UserNode';
import ResponseNode from './components/ResponseNode';

const API_BASE_URL = '/api';

// Define types
interface User {
  id: string;
  name: string;
}

interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

interface NodeData extends Record<string, unknown> {
  prompt?: string;
  content?: string;
  isLoading?: boolean;
  onPrompt?: (prompt: string) => void;
  branchCount?: number;
  nodeId?: string;
  chatHistory?: ChatMessage[]; // Store complete conversation history to this node
  parentNodeId?: string; // Track parent node for building history
}

const nodeTypes = {
  initial: InitialNode,
  user: UserNode,
  response: ResponseNode,
};

interface LoginModalProps {
  onLogin: (user: User) => void;
}

const LoginModal = ({ onLogin }: LoginModalProps) => {
  const [inputValue, setInputValue] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (inputValue.trim()) {
      const newUser: User = {
        id: inputValue.trim().toLowerCase().replace(/\s+/g, '-'),
        name: inputValue.trim()
      };
      onLogin(newUser);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
      <div className="bg-white p-8 rounded-lg shadow-xl max-w-md w-full">
        <h2 className="text-2xl font-bold text-gray-900 mb-6">Welcome to Interaction Flow</h2>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label htmlFor="username" className="block text-sm font-medium text-gray-700">
              Enter your name
            </label>
            <input
              type="text"
              id="username"
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 text-gray-900"
              placeholder="Your name"
              required
            />
          </div>
          <button
            type="submit"
            className="w-full px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600 transition-colors"
          >
            Start
          </button>
        </form>
      </div>
    </div>
  );
};

const Flow = () => {
  const [nodes, setNodes, onNodesChange] = useNodesState<Node<NodeData>>([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState<Edge>([]);
  const [user, setUser] = useState<User | null>(null);
  const [nodeCounter, setNodeCounter] = useState(0);

  // Helper function to build chat history for a node by traversing up the tree
  const buildChatHistory = (nodeId: string, currentNodes: Node<NodeData>[]): ChatMessage[] => {
    const node = currentNodes.find(n => n.id === nodeId);
    if (!node) return [];

    const history: ChatMessage[] = [];
    
    // If this node has a parent, get parent's history first
    if (node.data.parentNodeId) {
      const parentHistory = buildChatHistory(node.data.parentNodeId, currentNodes);
      history.push(...parentHistory);
    }

    // Add current node's contribution to history
    if (node.type === 'user' && node.data.prompt) {
      history.push({
        role: 'user',
        content: node.data.prompt
      });
    } else if (node.type === 'response' && node.data.content && !node.data.isLoading) {
      history.push({
        role: 'assistant',
        content: node.data.content
      });
    }

    return history;
  };

  const handleLogin = (newUser: User) => {
    setUser(newUser);
    setNodes([]);
    setEdges([]);
    setNodeCounter(1);
  };

  useEffect(() => {
    if (user && nodeCounter === 1 && nodes.length === 0) {
      const centerX = window.innerWidth / 2 - 150;
      const centerY = 100;

      const initialNode = {
        id: 'initial-0',
        type: 'initial',
        position: { x: centerX, y: centerY },
        data: {
          onPrompt: (prompt: string) => handleInitialPrompt(prompt, centerX, centerY),
          chatHistory: []
        },
      };
      setNodes([initialNode]);
    }
  }, [user, nodeCounter, nodes.length]);

  const handleInitialPrompt = async (prompt: string, initialX: number, initialY: number) => {
    if (!user || !user.id) {
      console.error('No user available for initial prompt');
      return;
    }

    const userNodeId = `user-${nodeCounter}`;
    const responseNodeId = `response-${nodeCounter}`;
    
    // Initial user node has empty chat history (it's the first message)
    const userChatHistory: ChatMessage[] = [];
    
    const userNode = {
      id: userNodeId,
      type: 'user',
      position: { x: initialX, y: initialY },
      data: { 
        prompt: prompt,
        chatHistory: userChatHistory,
        parentNodeId: undefined // No parent for initial user node
      },
    };
    
    // Response node will have the user's message in its history
    const responseChatHistory: ChatMessage[] = [
      { role: 'user', content: prompt }
    ];
    
    const responseNode = {
      id: responseNodeId,
      type: 'response',
      position: { x: initialX, y: initialY + 150 },
      data: {
        isLoading: true,
        onPrompt: (newPrompt: string) => handleBranch(responseNodeId, newPrompt),
        branchCount: 0,
        chatHistory: responseChatHistory,
        parentNodeId: userNodeId
      },
    };
    
    const responseEdge = {
      id: `edge-${userNodeId}-${responseNodeId}`,
      source: userNodeId,
      target: responseNodeId,
      sourceHandle: 'source',
      targetHandle: 'target',
      type: 'smoothstep',
      markerEnd: { type: MarkerType.ArrowClosed },
      animated: true,
      style: { stroke: '#64748b' }
    };
    
    setNodes(prevNodes => prevNodes.filter(node => node.id !== 'initial-0').concat(userNode, responseNode));
    setEdges([responseEdge]);
    setNodeCounter(prev => prev + 1);
    
    try {
      // For initial request, build chat history including the current user prompt
      const requestChatHistory = [{ role: 'user', content: prompt }];
      
      console.log('Sending initial chat history to API:', requestChatHistory); // Debug log
      
      const response = await fetch(`${API_BASE_URL}/interaction-nodes/start`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': user.id,
        },
        body: JSON.stringify({
          user_prompt: prompt,
          summary_title: null,
          context_messages: requestChatHistory // Send complete history including current prompt
        }),
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();

      // Update response node with content and complete chat history
      setNodes(prevNodes => 
        prevNodes.map(node => {
          if (node.id === responseNodeId) {
            const updatedChatHistory = [
              ...responseChatHistory,
              { role: 'assistant', content: data.llm_response }
            ];
            return { 
              ...node, 
              data: { 
                ...node.data, 
                content: data.llm_response, 
                isLoading: false, 
                nodeId: data.node_id,
                chatHistory: updatedChatHistory
              }
            };
          }
          return node;
        })
      );
    } catch (error) {
      console.error('Error getting response:', error);
      setNodes(prevNodes => 
        prevNodes.map(node => 
          node.id === responseNodeId 
            ? { ...node, data: { ...node.data, content: 'Error getting response. Please try again.', isLoading: false } }
            : node
        )
      );
    }
  };

  const handleBranch = useCallback((sourceResponseNodeId: string, prompt: string) => {
    if (!user) {
      console.error("Cannot branch: User is not logged in.");
      return;
    }

    setNodeCounter(currentCounter => {
        const newUserNodeId = `user-${currentCounter}`;
        const newResponseNodeId = `response-${currentCounter}`;

        setNodes(prevNodes => {
            const sourceNode = prevNodes.find(n => n.id === sourceResponseNodeId);
            const parentApiNodeId = sourceNode?.data?.nodeId;

            if (!parentApiNodeId) {
                console.error("Could not find source node's API ID to create a branch.");
                return prevNodes;
            }

            // Build chat history for the new user node (includes all conversation up to parent response)
            const parentChatHistory = buildChatHistory(sourceResponseNodeId, prevNodes);
            const userChatHistory = parentChatHistory; // User node stores history up to this point (without its own prompt)
            const requestChatHistory = [
                ...parentChatHistory,
                { role: 'user', content: prompt }
            ]; // Complete history including new prompt for API request

            const currentBranchCount = sourceNode.data.branchCount || 0;
            const branchSpacing = 350;
            const verticalOffset = 200;
            const totalWidth = currentBranchCount * branchSpacing;
            const startX = sourceNode.position.x - totalWidth / 2;

            const newUserX = startX + (currentBranchCount * branchSpacing);
            const newUserY = sourceNode.position.y + verticalOffset;

            const newUserNode = {
                id: newUserNodeId,
                type: 'user',
                position: { x: newUserX, y: newUserY },
                data: { 
                    prompt: prompt,
                    chatHistory: userChatHistory, // User node stores history up to this point (without its own prompt)
                    parentNodeId: sourceResponseNodeId
                },
            };

            const newResponseNode = {
                id: newResponseNodeId,
                type: 'response',
                position: { x: newUserX, y: newUserY + 150 },
                data: {
                    isLoading: true,
                    onPrompt: (newPrompt: string) => handleBranch(newResponseNodeId, newPrompt),
                    branchCount: 0,
                    chatHistory: requestChatHistory, // Response node gets complete history including new user message
                    parentNodeId: newUserNodeId
                },
            };

            const updatedSourceNode = {
                ...sourceNode,
                data: {
                    ...sourceNode.data,
                    branchCount: currentBranchCount + 1,
                },
            };

            setEdges(prevEdges => {
                const userEdge = {
                    id: `edge-${sourceResponseNodeId}-${newUserNodeId}`,
                    source: sourceResponseNodeId,
                    target: newUserNodeId,
                    sourceHandle: 'source',
                    targetHandle: 'target',
                    type: 'smoothstep',
                    markerEnd: { type: MarkerType.ArrowClosed },
                };
                const responseEdge = {
                    id: `edge-${newUserNodeId}-${newResponseNodeId}`,
                    source: newUserNodeId,
                    target: newResponseNodeId,
                    sourceHandle: 'source',
                    targetHandle: 'target',
                    type: 'smoothstep',
                    markerEnd: { type: MarkerType.ArrowClosed },
                };
                return [...prevEdges, userEdge, responseEdge];
            });

            // Async side effect: fetch branch response with complete chat history
            (async () => {
                try {
                    console.log('Sending chat history to API:', requestChatHistory); // Debug log

                    const response = await fetch(`${API_BASE_URL}/interaction-nodes/${parentApiNodeId}/branch`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'x-user-id': user.id,
                        },
                        body: JSON.stringify({ 
                            user_prompt: prompt, 
                            summary_title: null,
                            context_messages: requestChatHistory // Send complete conversation history including current prompt
                        }),
                    });

                    if (!response.ok) {
                        throw new Error(`HTTP error! status: ${response.status}`);
                    }

                    const data = await response.json();

                    // Update response node with content and complete chat history
                    setNodes(nodesAfter => 
                        nodesAfter.map(node => {
                            if (node.id === newResponseNodeId) {
                                const completeChatHistory = [
                                    ...requestChatHistory,
                                    { role: 'assistant', content: data.llm_response }
                                ];
                                return { 
                                    ...node, 
                                    data: { 
                                        ...node.data, 
                                        content: data.llm_response, 
                                        isLoading: false, 
                                        nodeId: data.node_id,
                                        chatHistory: completeChatHistory
                                    }
                                };
                            }
                            return node;
                        })
                    );
                } catch (error) {
                    console.error('Error creating branch:', error);
                    setNodes(nodesAfter =>
                        nodesAfter.map(node =>
                            node.id === newResponseNodeId
                                ? { ...node, data: { ...node.data, content: 'Error creating branch. Please try again.', isLoading: false } }
                                : node
                        )
                    );
                }
            })();

            return prevNodes
                .map(node => (node.id === sourceResponseNodeId ? updatedSourceNode : node))
                .concat(newUserNode, newResponseNode);
        });
        
        return currentCounter + 1;
    });
  }, [user]);

  const startNewConversation = () => {
    if (!user) {
      console.error("Cannot start new conversation: no user logged in.");
      return;
    }
    setNodes([]);
    setEdges([]);
    setNodeCounter(1);
  };

  const onConnect = useCallback((params: any) => {
    return true;
  }, []);

  const isValidConnection = useCallback((connection: any) => {
    return true;
  }, []);

  if (!user) {
    return <LoginModal onLogin={handleLogin} />;
  }

  return (
    <div className="h-screen">
      <ReactFlow
        nodes={nodes}
        edges={edges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        onConnect={onConnect}
        isValidConnection={isValidConnection}
        nodeTypes={nodeTypes}
        fitView
      >
        <Background />
        <Controls />
        <Panel position="top-right" className="bg-white p-4 rounded-lg shadow-lg">
          <div className="flex items-center gap-4">
            <span className="text-gray-600">Welcome, {user.name}</span>
            <button
              onClick={startNewConversation}
              className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
            >
              New Conversation
            </button>
          </div>
        </Panel>
      </ReactFlow>
    </div>
  );
};

const App = () => {
  return (
    <ReactFlowProvider>
      <Flow />
    </ReactFlowProvider>
  );
};

export default App;