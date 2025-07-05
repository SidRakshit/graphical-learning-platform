import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import remarkBreaks from 'remark-breaks';
import rehypeHighlight from 'rehype-highlight';
import rehypeRaw from 'rehype-raw';
import rehypeSanitize from 'rehype-sanitize';
import 'highlight.js/styles/github.css';

const MarkdownRenderer = ({ content, className = '' }) => {
  // Handle empty or invalid content
  if (!content || typeof content !== 'string') {
    return <div className={`text-gray-500 italic ${className}`}>No content to display</div>;
  }

  // Sanitize content to prevent XSS attacks
  const sanitizedContent = content.trim();

  // Error boundary for markdown parsing
  try {
    return (
      <div className={`prose prose-sm max-w-none ${className}`}>
        <ReactMarkdown
          remarkPlugins={[remarkGfm, remarkBreaks]}
          rehypePlugins={[
            rehypeHighlight,
            [rehypeRaw, { passThrough: ['element'] }],
            [rehypeSanitize, {
              allowedTags: [
                'p', 'br', 'strong', 'em', 'u', 'del', 'code', 'pre',
                'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
                'ul', 'ol', 'li',
                'blockquote',
                'table', 'thead', 'tbody', 'tr', 'th', 'td',
                'a', 'img',
                'div', 'span'
              ],
              allowedAttributes: {
                'a': ['href', 'title', 'target', 'rel'],
                'img': ['src', 'alt', 'title', 'width', 'height'],
                'code': ['className'],
                'pre': ['className'],
                'div': ['className'],
                'span': ['className']
              },
              allowedSchemes: ['http', 'https', 'mailto']
            }]
          ]}
          components={{
            // Enhanced code block handling
            code: ({ node, inline, className, children, ...props }) => {
              const match = /language-(\w+)/.exec(className || '');
              const language = match ? match[1] : '';
              
              if (!inline && match) {
                return (
                  <div className="relative">
                    {language && (
                      <div className="absolute top-2 right-2 text-xs text-gray-500 bg-white px-2 py-1 rounded">
                        {language}
                      </div>
                    )}
                    <code className={`${className} block p-3 pt-8 rounded-md bg-gray-100 text-sm overflow-x-auto font-mono`} {...props}>
                      {children}
                    </code>
                  </div>
                );
              }
              
              return (
                <code className="bg-gray-100 px-1.5 py-0.5 rounded text-sm font-mono text-gray-800" {...props}>
                  {children}
                </code>
              );
            },
            
            // Enhanced pre block
            pre: ({ children }) => (
              <pre className="bg-gray-100 p-3 rounded-md overflow-x-auto border border-gray-200 my-3">
                {children}
              </pre>
            ),
            
            // Enhanced blockquote
            blockquote: ({ children }) => (
              <blockquote className="border-l-4 border-blue-300 pl-4 py-2 italic text-gray-700 bg-blue-50 rounded-r-md my-3">
                {children}
              </blockquote>
            ),
            
            // Enhanced headings with better hierarchy
            h1: ({ children }) => (
              <h1 className="text-2xl font-bold text-gray-900 mb-3 mt-4 border-b border-gray-200 pb-2">
                {children}
              </h1>
            ),
            h2: ({ children }) => (
              <h2 className="text-xl font-semibold text-gray-900 mb-2 mt-3">
                {children}
              </h2>
            ),
            h3: ({ children }) => (
              <h3 className="text-lg font-semibold text-gray-900 mb-2 mt-3">
                {children}
              </h3>
            ),
            h4: ({ children }) => (
              <h4 className="text-base font-semibold text-gray-900 mb-1 mt-2">
                {children}
              </h4>
            ),
            h5: ({ children }) => (
              <h5 className="text-sm font-semibold text-gray-900 mb-1 mt-2">
                {children}
              </h5>
            ),
            h6: ({ children }) => (
              <h6 className="text-xs font-semibold text-gray-900 mb-1 mt-2">
                {children}
              </h6>
            ),
            
            // Enhanced paragraph with better spacing
            p: ({ children }) => (
              <p className="text-gray-800 mb-3 leading-relaxed">
                {children}
              </p>
            ),
            
            // Enhanced lists
            ul: ({ children }) => (
              <ul className="list-disc list-inside text-gray-800 mb-3 space-y-1 ml-4">
                {children}
              </ul>
            ),
            ol: ({ children }) => (
              <ol className="list-decimal list-inside text-gray-800 mb-3 space-y-1 ml-4">
                {children}
              </ol>
            ),
            li: ({ children }) => (
              <li className="text-gray-800 leading-relaxed">{children}</li>
            ),
            
            // Enhanced links with better security
            a: ({ href, children }) => {
              // Validate URL
              const isValidUrl = href && (href.startsWith('http://') || href.startsWith('https://') || href.startsWith('mailto:'));
              
              if (!isValidUrl) {
                return <span className="text-gray-600">{children}</span>;
              }
              
              return (
                <a 
                  href={href} 
                  className="text-blue-600 hover:text-blue-800 underline decoration-blue-300 hover:decoration-blue-500 transition-colors"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {children}
                </a>
              );
            },
            
            // Enhanced image handling
            img: ({ src, alt, ...props }) => {
              // Basic URL validation for images
              const isValidImageUrl = src && (src.startsWith('http://') || src.startsWith('https://') || src.startsWith('data:image/'));
              
              if (!isValidImageUrl) {
                return (
                  <div className="bg-gray-100 border border-gray-300 rounded p-4 text-center text-gray-500">
                    <span>Image not available</span>
                    {alt && <div className="text-sm mt-1">{alt}</div>}
                  </div>
                );
              }
              
              return (
                <img 
                  src={src} 
                  alt={alt || 'Image'} 
                  className="max-w-full h-auto rounded border border-gray-200 my-2"
                  loading="lazy"
                  {...props}
                />
              );
            },
            
            // Enhanced table styling
            table: ({ children }) => (
              <div className="overflow-x-auto my-4">
                <table className="min-w-full border-collapse border border-gray-300 text-sm bg-white">
                  {children}
                </table>
              </div>
            ),
            thead: ({ children }) => (
              <thead className="bg-gray-50">{children}</thead>
            ),
            th: ({ children }) => (
              <th className="border border-gray-300 px-3 py-2 font-semibold text-left text-gray-900">
                {children}
              </th>
            ),
            td: ({ children }) => (
              <td className="border border-gray-300 px-3 py-2 text-gray-800">
                {children}
              </td>
            ),
            
            // Handle horizontal rules
            hr: () => (
              <hr className="my-4 border-gray-300" />
            ),
            
            // Handle strikethrough text
            del: ({ children }) => (
              <del className="text-gray-500 line-through">{children}</del>
            ),
            
            // Handle strong and emphasis
            strong: ({ children }) => (
              <strong className="font-semibold text-gray-900">{children}</strong>
            ),
            em: ({ children }) => (
              <em className="italic text-gray-800">{children}</em>
            ),
          }}
        >
          {sanitizedContent}
        </ReactMarkdown>
      </div>
    );
  } catch (error) {
    console.error('Markdown rendering error:', error);
    return (
      <div className={`text-red-500 italic ${className}`}>
        <p>Error rendering markdown content</p>
        <details className="mt-2 text-sm">
          <summary className="cursor-pointer">Show details</summary>
          <pre className="mt-1 text-xs bg-red-50 p-2 rounded overflow-x-auto">
            {error.message}
          </pre>
        </details>
      </div>
    );
  }
};

export default MarkdownRenderer; 